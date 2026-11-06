#!/usr/bin/env bash
# Copyright (c) 2026, Frappe Technologies Pvt. Ltd. and contributors
# For license information, please see license.txt
#
# Install Frappe Books, on one command, on Debian or Ubuntu (a server, a laptop
# or WSL2 on Windows).
#
#   ./install-books.sh                          # site books.localhost on port 80
#   ./install-books.sh --port 8000 --dev        # WSL2 or a shared laptop
#
# The script installs MariaDB, Redis, nginx, supervisor, Node.js and Python
# 3.14, creates a bench with Frappe and Books, makes a site, installs Books on
# it, builds the /books assets, serves it with nginx and supervisor, enables
# the scheduler and adds a nightly backup to the crontab. It is safe to run
# again: a step that is already done is skipped.
#
# Run it as your own user, not as root: it asks for sudo where it needs it.

set -Eeuo pipefail

APP_REPO="${APP_REPO:-https://github.com/frappe/frappe-books}"
APP_REF="${APP_REF:-v16.1.0}"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-16}"
BENCH_DIR="${BENCH_DIR:-$HOME/frappe-bench}"
SITE="${SITE:-books.localhost}"
PORT="${PORT:-80}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_USER="books"
MODE="production"
APP_SOURCE="auto"
CHECK=0

usage() {
  cat <<'EOF'
Install Frappe Books on Debian or Ubuntu, including WSL2.

Usage: ./install-books.sh [options]

Options:
  --site NAME             site to create (default: books.localhost)
  --port PORT             port nginx (or the dev server) listens on (default: 80)
  --admin-password PASS   Administrator password (default: generated)
  --db-password PASS      password of the MariaDB user the script creates
                          (default: generated)
  --bench-dir PATH        bench directory (default: ~/frappe-bench)
  --app-ref REF           Books git ref to install (default: v16.1.0)
  --frappe-branch BRANCH  Frappe branch to install (default: version-16)
  --dev                   do not set up nginx and supervisor; run
                          `bench start` instead (use on WSL2 or a test machine)
  --local-app             install the Books checkout this script sits in,
                          instead of cloning it from GitHub
  --remote-app            always clone Books from GitHub
  --check                 only report whether this machine can run Books
  -h, --help              show this help

What it does:
  1. installs git, MariaDB, Redis, nginx, supervisor, Node.js, yarn, Python 3.14
  2. creates the MariaDB user `books` with a generated password
  3. installs bench (through uv) and creates a bench with Frappe
  4. installs Books on the bench and creates the site
  5. builds the assets, sets up nginx and supervisor, starts everything
  6. enables the scheduler and adds a nightly backup to your crontab

The admin and database passwords are printed at the end and saved to
~/.frappe-books-install. Open the site, then /books, to run the setup wizard.
EOF
}

info() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

trap 'printf "\n\033[1mFailed\033[0m at line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

while [[ $# -gt 0 ]]; do
  case "$1" in
    --site) SITE="${2:?--site needs a value}"; shift 2 ;;
    --port) PORT="${2:?--port needs a value}"; shift 2 ;;
    --admin-password) ADMIN_PASSWORD="${2:?--admin-password needs a value}"; shift 2 ;;
    --db-password) DB_PASSWORD="${2:?--db-password needs a value}"; shift 2 ;;
    --bench-dir) BENCH_DIR="${2:?--bench-dir needs a value}"; shift 2 ;;
    --app-ref) APP_REF="${2:?--app-ref needs a value}"; shift 2 ;;
    --frappe-branch) FRAPPE_BRANCH="${2:?--frappe-branch needs a value}"; shift 2 ;;
    --dev) MODE="dev"; shift ;;
    --local-app) APP_SOURCE="local"; shift ;;
    --remote-app) APP_SOURCE="remote"; shift ;;
    --check) CHECK=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

# ---------------------------------------------------------------- preflight --

BOOKS_USER=$(id -un)
[[ ${EUID:-0} -ne 0 ]] || die "run this as your normal user, not as root: it asks for sudo when it needs it"
command -v sudo >/dev/null 2>&1 || die "sudo is required"
command -v systemctl >/dev/null 2>&1 || die "systemd is required (the script sets up services)"

[[ $PORT =~ ^[0-9]+$ ]] || die "--port must be a number"
((PORT > 0 && PORT < 65536)) || die "--port must be between 1 and 65535"
[[ $SITE =~ ^[a-z0-9][a-z0-9.-]*$ ]] || die "--site must be a lowercase hostname, like books.localhost"

# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}${ID_LIKE:-}" in
  *ubuntu* | *debian*) ;;
  *) die "this script supports Debian and Ubuntu (found: ${PRETTY_NAME:-unknown})" ;;
esac

if grep -qi microsoft /proc/version 2>/dev/null; then
  note "WSL2 detected: serve on a port above 1024 (--port 8000), not 80"
fi

MEM_KB=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)
((MEM_KB > 1500000)) || warn "only $((MEM_KB / 1024)) MB of RAM: MariaDB, Redis and the web workers want 2 GB or more"
AVAIL_KB=$(df -Pk / | awk 'NR == 2 { print $4 }')
((AVAIL_KB > 5000000)) || warn "less than 5 GB free on /: the bench, MariaDB and the assets need about 5 GB"

if ((CHECK)); then
  printf '\n%s\n' "$(printf '\033[1mThis machine\033[0m')"
  printf '  OS        : %s\n' "${PRETTY_NAME:-unknown}"
  printf '  memory    : %s MB total\n' "$((MEM_KB / 1024))"
  printf '  disk free : %s GB on /\n' "$((AVAIL_KB / 1024 / 1024))"
  printf '  WSL       : %s\n' "$(grep -qi microsoft /proc/version 2>/dev/null && echo yes || echo no)"
  printf '  sudo      : %s\n' "$(command -v sudo >/dev/null 2>&1 && echo yes || echo no)"
  printf '  node      : %s\n' "$(command -v node >/dev/null 2>&1 && node -v || echo 'will install')"
  printf '  python3.14: %s\n' "$(command -v python3.14 >/dev/null 2>&1 && python3.14 -V 2>&1 || echo 'will install')"
  printf '  bench     : %s\n' "$( [[ -d $BENCH_DIR/apps ]] && echo "reuses $BENCH_DIR" || echo "creates $BENCH_DIR")"
  if ((PORT < 1024)); then
    printf '  port      : %s (a privileged port: fine for nginx, not for --dev)\n' "$PORT"
  else
    printf '  port      : %s\n' "$PORT"
  fi
  printf '  site      : %s\n\n' "$SITE"
  exit 0
fi

sudo -v || die "sudo is required"
# Keep the sudo timestamp fresh while the install runs. The loop writes to
# /dev/null so it cannot hold open a pipe the caller is reading.
(while true; do sudo -n true; sleep 60; done) >/dev/null 2>&1 &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

DB_PASSWORD_GIVEN=0
[[ -n $DB_PASSWORD ]] && DB_PASSWORD_GIVEN=1
[[ -z $DB_PASSWORD || $DB_PASSWORD =~ ^[A-Za-z0-9._-]+$ ]] ||
  die "--db-password may only use letters, digits, dot, dash and underscore"

# A rerun keeps the passwords the first run made.
CREDENTIALS="$HOME/.frappe-books-install"
ADMIN_PASSWORD_STATE=""
if [[ -z $ADMIN_PASSWORD && -f $CREDENTIALS ]]; then
  ADMIN_PASSWORD=$(sed -n 's/^ADMIN_PASSWORD=//p' "$CREDENTIALS")
fi

# ------------------------------------------------------- system packages ----

info "Installing system packages"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  git curl ca-certificates gnupg build-essential pkg-config \
  libffi-dev libssl-dev zlib1g-dev libjpeg-dev \
  libmariadb-dev libmariadb-dev-compat libcups2-dev \
  libpango-1.0-0 libharfbuzz-subset0 libxrender1 libxext6 libx11-6 fontconfig xvfb \
  mariadb-server mariadb-client redis-server nginx supervisor
sudo apt-get install -y --no-install-recommends cron ||
  warn "cron is not available: add the nightly backup to whatever runs timers here"
sudo apt-get install -y --no-install-recommends wkhtmltopdf ||
  warn "wkhtmltopdf is not available: printing to PDF may fail (the browser's print dialog still works)"

NODE_MAJOR=0
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
fi
if ((NODE_MAJOR < 20)); then
  info "Installing Node.js 24"
  curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  note "Node.js $(node -v) is new enough"
fi
# Debian's "yarn" package is cmdtest, not the package manager bench needs.
YARN_VERSION=""
if command -v yarn >/dev/null 2>&1; then
  YARN_VERSION=$(yarn --version 2>/dev/null || true)
fi
if [[ $YARN_VERSION != 1.* ]]; then
  sudo npm install -g --silent yarn@1.22.22
fi

# ------------------------------------------------------------- python/uv ----

export PATH="$HOME/.local/bin:$PATH"
info "Preparing Python 3.14 and bench"

PYTHON_BIN=""
if command -v python3.14 >/dev/null 2>&1; then
  PYTHON_BIN=$(command -v python3.14)
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 14) else 1)'; then
  PYTHON_BIN=$(command -v python3)
fi

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

if [[ -z $PYTHON_BIN ]]; then
  note "Python 3.14 is not installed: fetching it with uv"
  uv python install 3.14
  PYTHON_BIN=$(uv python find 3.14)
fi
note "Python: $PYTHON_BIN ($("$PYTHON_BIN" -V 2>&1))"

if ! command -v bench >/dev/null 2>&1; then
  uv tool install frappe-bench
  export PATH="$HOME/.local/bin:$PATH"
fi
BENCH_BIN=$(command -v bench)
note "bench: $BENCH_BIN"

# ---------------------------------------------------------------- database --

info "Configuring MariaDB"
sudo mkdir -p /etc/mysql/mariadb.conf.d
if [[ ! -f /etc/mysql/mariadb.conf.d/99-frappe-books.cnf ]]; then
  sudo tee /etc/mysql/mariadb.conf.d/99-frappe-books.cnf >/dev/null <<'CNF'
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
innodb_file_per_table = 1
innodb_buffer_pool_size = 256M
max_connections = 200
CNF
  note "wrote /etc/mysql/mariadb.conf.d/99-frappe-books.cnf"
fi
sudo systemctl enable --now mariadb
sudo systemctl restart mariadb
for _ in $(seq 1 30); do
  sudo mariadb-admin ping >/dev/null 2>&1 && break
  sleep 1
done
sudo mariadb-admin ping >/dev/null 2>&1 || die "MariaDB did not start: see sudo journalctl -u mariadb"

# bench creates site databases and users with this account.
DB_USER_EXISTS=$(sudo mariadb --batch --skip-column-names \
  -e "SELECT COUNT(*) FROM mysql.user WHERE user = '$DB_USER' AND host = '%'")
SITE_CONFIG="$BENCH_DIR/sites/$SITE/site_config.json"
if [[ $DB_USER_EXISTS == 0 ]]; then
  # A site that already exists must keep talking to the same password.
  if [[ -z $DB_PASSWORD && -f $SITE_CONFIG ]]; then
    DB_PASSWORD=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("db_password") or "")' "$SITE_CONFIG")
  fi
  [[ -n $DB_PASSWORD ]] || DB_PASSWORD=$(openssl rand -hex 12)
  sudo mariadb <<SQL
CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
  note "created database user '$DB_USER'"
elif ((DB_PASSWORD_GIVEN)); then
  sudo mariadb <<SQL
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
FLUSH PRIVILEGES;
SQL
  note "set the password of database user '$DB_USER'"
elif [[ -f $SITE_CONFIG ]]; then
  # The site already knows the password; changing it would lock the site out.
  DB_PASSWORD=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("db_password") or "")' "$SITE_CONFIG")
  [[ -n $DB_PASSWORD ]] ||
    die "database user '$DB_USER' exists and its password is unknown: rerun with --db-password"
  note "reusing the database password of the existing site"
else
  die "database user '$DB_USER' exists but no site uses it: rerun with --db-password"
fi

info "Starting Redis"
sudo systemctl enable --now redis-server

# ------------------------------------------------------------------- bench --

info "Creating the bench at $BENCH_DIR"
mkdir -p "$(dirname "$BENCH_DIR")"
if [[ -d $BENCH_DIR/apps ]]; then
  note "bench already exists: reusing it"
else
  "$BENCH_BIN" init "$BENCH_DIR" --frappe-branch "$FRAPPE_BRANCH" --python "$PYTHON_BIN"
fi
cd "$BENCH_DIR"

# One Redis service for cache, queue and realtime, on separate databases.
"$BENCH_BIN" set-config -g redis_cache "redis://127.0.0.1:6379/0"
"$BENCH_BIN" set-config -g redis_queue "redis://127.0.0.1:6379/1"
"$BENCH_BIN" set-config -g redis_socketio "redis://127.0.0.1:6379/2"

# --------------------------------------------------------------- the app ----

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $APP_SOURCE == "auto" ]]; then
  if [[ -f $REPO_ROOT/frappe_books/hooks.py ]]; then APP_SOURCE="local"; else APP_SOURCE="remote"; fi
fi

info "Installing Frappe Books ($APP_SOURCE)"
if [[ -d apps/frappe_books ]]; then
  note "frappe_books is already on the bench: reusing it"
elif [[ $APP_SOURCE == "local" ]]; then
  "$BENCH_BIN" get-app "$REPO_ROOT"
else
  "$BENCH_BIN" get-app "$APP_REPO" --branch "$APP_REF"
fi

# -------------------------------------------------------------------- site --

info "Creating site $SITE"
if [[ -d sites/$SITE ]]; then
  note "site already exists: reusing it"
  [[ -n $ADMIN_PASSWORD ]] || ADMIN_PASSWORD_STATE="the site existed already: set a new one with bench --site $SITE set-admin-password"
else
  [[ -n $ADMIN_PASSWORD ]] || ADMIN_PASSWORD=$(openssl rand -hex 8)
  "$BENCH_BIN" new-site "$SITE" \
    --db-host 127.0.0.1 --db-port 3306 \
    --db-root-username "$DB_USER" --db-root-password "$DB_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD"
fi

if "$BENCH_BIN" --site "$SITE" list-apps | grep -qx frappe_books; then
  note "Books is already installed on $SITE"
else
  "$BENCH_BIN" --site "$SITE" install-app frappe_books
fi

# Serve the site whatever name a browser asks for: an IP, localhost, a tailnet
# name. Books resolves the site from the default site, so any Host works.
info "Building assets"
"$BENCH_BIN" build
"$BENCH_BIN" --site "$SITE" migrate

# ------------------------------------------------------------- production --

HOST_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')
[[ -n $HOST_IP ]] || HOST_IP=$(hostname -I 2>/dev/null | awk '{ print $1 }')
HOST_IP=${HOST_IP:-localhost}
# In WSL2 the Linux address is not what a phone on the same wifi can reach.
if grep -qi microsoft /proc/version 2>/dev/null; then HOST_IP="localhost"; fi
if ((PORT == 80)); then
  HOST_URL="http://$HOST_IP"
else
  HOST_URL="http://$HOST_IP:$PORT"
fi

if [[ $MODE == "production" ]]; then
  info "Serving Books with nginx and supervisor"
  # bench listens on the site's nginx_port; leaves the site on 80 otherwise.
  "$BENCH_BIN" --site "$SITE" set-config nginx_port "$PORT"
  "$BENCH_BIN" setup nginx --yes
  # Redis is the system service here, so supervisor runs the app only.
  "$BENCH_BIN" setup supervisor --user "$BOOKS_USER" --yes --skip-redis --skip-supervisord

  sudo ln -sfn "$BENCH_DIR/config/nginx.conf" /etc/nginx/conf.d/frappe-books.conf
  sudo ln -sfn "$BENCH_DIR/config/supervisor.conf" /etc/supervisor/conf.d/frappe-books.conf
  if ((PORT == 80)); then
    # The stock nginx site takes every unnamed request on port 80.
    sudo rm -f /etc/nginx/sites-enabled/default
  fi

  # Refuse a broken configuration before nginx is restarted with it.
  sudo nginx -t
  sudo systemctl enable --now nginx supervisor mariadb redis-server
  sudo systemctl reload nginx
  sudo supervisorctl reread
  sudo supervisorctl update
  sudo supervisorctl restart all
else
  info "Dev mode: no nginx, no supervisor"
  HOST_URL="http://localhost:8000"
fi

# --------------------------------------------------------------- settings --

"$BENCH_BIN" --site "$SITE" set-config host_name "$HOST_URL"
"$BENCH_BIN" --site "$SITE" enable-scheduler

# ----------------------------------------------------------------- backups --

BACKUP_LOG="$HOME/frappe-books-backup.log"
BACKUP_SCRIPT="$BENCH_DIR/apps/frappe_books/deploy/backup-books.sh"
if [[ -f $BACKUP_SCRIPT ]]; then
  chmod +x "$BACKUP_SCRIPT"
  CRON_LINE="15 2 * * * cd $BENCH_DIR && BENCH_DIR=$BENCH_DIR SITE=$SITE KEEP_DAYS=14 $BACKUP_SCRIPT >> $BACKUP_LOG 2>&1 # frappe-books"
else
  CRON_LINE="15 2 * * * cd $BENCH_DIR && $BENCH_BIN --site $SITE backup --with-files >> $BACKUP_LOG 2>&1 # frappe-books"
fi
if command -v crontab >/dev/null 2>&1; then
  if [[ $MODE == "production" ]]; then
    sudo systemctl enable --now cron >/dev/null 2>&1 || warn "could not start cron"
  fi
  {
    crontab -l 2>/dev/null | grep -v '# frappe-books$' || true
    echo "$CRON_LINE"
  } | crontab -
  note "nightly backup in your crontab at 02:15"
fi

(
  umask 077
  cat >"$CREDENTIALS" <<EOF
# Frappe Books, installed $(date -Iseconds)
URL=$HOST_URL/books
SITE=$SITE
ADMIN_USER=Administrator
ADMIN_PASSWORD=${ADMIN_PASSWORD:-${ADMIN_PASSWORD_STATE:-unknown}}
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
BENCH_DIR=$BENCH_DIR
EOF
)

CREDENTIALS_NOTE="saved to $CREDENTIALS"
cat <<EOF

$(printf '\033[1mFrappe Books is installed\033[0m')

  URL          : $HOST_URL/books
  Site         : $SITE
  Administrator: ${ADMIN_PASSWORD:-$ADMIN_PASSWORD_STATE}
  Database     : $DB_USER / $DB_PASSWORD
  Bench        : $BENCH_DIR
  Passwords    : $CREDENTIALS_NOTE

Next:
  1. open $HOST_URL/books and sign in as Administrator
  2. the setup wizard asks for your company, country, currency and fiscal year
  3. invite the people who need access from the Frappe user list

$(
    if [[ $MODE == "dev" ]]; then
      printf 'Start it with: cd %s && bench start\n' "$BENCH_DIR"
    else
      printf 'Backups run nightly into %s/sites/%s/private/backups.\n' "$BENCH_DIR" "$SITE"
      printf 'Copy them off the machine with rclone, or set RCLONE_REMOTE for deploy/backup-books.sh.\n'
    fi
  )
EOF
