# Installing Frappe Books on your own machine

Two scripts, one command each. `install-books.sh` does the work on Debian or
Ubuntu; `install-books.ps1` sets up WSL2 on a Windows laptop and then runs the
first one inside it.

They install Frappe, Books, MariaDB, Redis, nginx, supervisor, Node.js and
Python 3.14, create a site, build the assets, serve `/books`, enable the
scheduler and add a nightly backup to your crontab. Running one again is safe:
steps that are already done are skipped.

## Windows laptop

In an **Administrator** PowerShell, from this folder:

```powershell
.\install-books.ps1
```

Then open <http://localhost:8000/books>. The first run may ask for a restart,
because Windows has to enable WSL2 first.

It installs Ubuntu in WSL2, creates the Linux user `books`, copies the bash
installer into `/opt/books` and runs it, opens the port to your wifi, and
registers a "Frappe Books" task that starts the server when you sign in.

| Option | Effect |
| --- | --- |
| `-Port 8080` | serve on another port (default 8000) |
| `-Site books.localhost` | name of the Frappe site |
| `-AdminPassword`, `-DbPassword` | set the passwords yourself |
| `-SkipMirroredNetworking` | do not edit `%USERPROFILE%\.wslconfig` |
| `-NoAutostart` | do not register the sign-in task |

## Ubuntu / Debian, server or WSL2 by hand

```bash
chmod +x install-books.sh
./install-books.sh                 # site books.localhost on port 80
./install-books.sh --port 8000     # WSL2, or a laptop that does not own port 80
./install-books.sh --check         # only report whether this machine can host it
```

Run it as your own user: it asks for sudo when it needs it. It refuses to run as
root, because bench must not be owned by root.

| Option | Effect |
| --- | --- |
| `--site NAME` | site name (default `books.localhost`) |
| `--port PORT` | port nginx listens on (default 80) |
| `--admin-password`, `--db-password` | set the passwords yourself |
| `--bench-dir PATH` | where the bench goes (default `~/frappe-bench`) |
| `--app-ref REF` | Books version to install (default `v16.1.0`) |
| `--frappe-branch BRANCH` | Frappe branch (default `version-16`) |
| `--dev` | skip nginx and supervisor; run `bench start` instead |
| `--local-app` | install the checkout this script sits in, not the clone from GitHub |
| `--check` | report only: OS, memory, disk, node, python, existing bench |

## What you get

- `http://<host>:<port>/books`, served by nginx and gunicorn under supervisor
- a Frappe site named `books.localhost`, with `Administrator` as the user
- the scheduler running (Books uses it to expire loyalty points daily)
- nightly backups at 02:15 through `deploy/backup-books.sh`, which prunes
  copies older than 14 days and copies them to `RCLONE_REMOTE` if it is set
- passwords in `~/.frappe-books-install` (mode 600) and printed once at the end

Open `/books` after signing in: the setup wizard asks for the company, country,
currency and fiscal year, and completes Frappe's setup with them.

## Backups

`install-books.sh` puts this in your crontab, and you can run it by hand:

```bash
BENCH_DIR=~/frappe-bench SITE=books.localhost KEEP_DAYS=30 \
  RCLONE_REMOTE=r2:books-backups ./backup-books.sh
```

A backup on the same laptop is not a backup. Configure `rclone` for Backblaze
B2, Cloudflare R2 or S3, and test a restore once:

```bash
bench --site books.localhost restore ~/frappe-bench/sites/books.localhost/private/backups/<db>.sql.gz \
  --with-public-files <files>.tar --with-private-files <private-files>.tar
```

## Updating

```bash
cd ~/frappe-bench
bench --site books.localhost backup --with-files
git -C apps/frappe_books fetch --tags && git -C apps/frappe_books checkout v16.1.0
bench setup requirements
bench --site books.localhost migrate
bench build
sudo supervisorctl restart all
```

Pin the version you run: `--app-ref v16.1.0` installs a release, while the
`develop` branch of Books tracks Frappe 17 and changes daily.

## Making it reachable from outside the laptop

Do not forward ports on your router. Either:

- **Cloudflare Tunnel**: `cloudflared tunnel --url http://localhost:8000`, or a
  named tunnel with Cloudflare Access in front, or
- **Tailscale**: `tailscale serve --bg 8000`, which gives HTTPS on your tailnet
  and needs no domain, or
- **A real server**: run `install-books.sh` on a VPS and put
  `bench setup lets-encrypt books.example.com` in front of it.

Set the final address so print formats and emails use it:

```bash
bench --site books.localhost set-config host_name https://books.example.com
```

## Troubleshooting

**`bench: command not found`.** bench lives in `~/.local/bin`, which older
shells do not always load. `export PATH="$HOME/.local/bin:$PATH"`.

**nginx fails to start.** `sudo nginx -t` names the file and line. Another
service usually owns the port: pick another with `--port`.

**"database user 'books' exists but no site uses it".** An earlier run created
the MariaDB user but no site. Pass the password that user has:
`--db-password <that password>`, or drop the user and start again.

**"the site existed already: set a new one with ...".** A rerun cannot know the
Administrator password if `~/.frappe-books-install` is gone. Set a new one:

```bash
bench --site books.localhost set-admin-password
```

**Page loads but Books says the site is not set up.** Open `/books` rather than
`/`, and finish the wizard.

**Everything stops when the laptop sleeps or `wsl --shutdown` runs.** Set
Windows to never sleep while plugged in, and rerun the "Frappe Books" scheduled
task (or reboot) to start it again.

**In WSL2, the site is reachable from Windows but not from a phone.** Windows 11
22H2 and newer use mirrored networking, which the PowerShell script turns on.
Older builds need a port proxy:
`netsh interface portproxy add v4tov4 listenport=8000 listenaddress=0.0.0.0 connectport=8000 connectaddress=<wsl ip>`.

## A caveat

These scripts are not covered by this repository's CI, and they install pinned
versions that will age. Read the script before running it on a machine that
matters, keep the backups off the machine, and try it on a scratch install
first. The versions they set are the ones in the `DEFAULT` block at the top of
`install-books.sh` and the `param()` block of `install-books.ps1`.
