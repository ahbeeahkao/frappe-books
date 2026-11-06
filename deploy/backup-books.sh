#!/usr/bin/env bash
# Copyright (c) 2026, Frappe Technologies Pvt. Ltd. and contributors
# For license information, please see license.txt
#
# Back up a Frappe Books site, prune old copies and copy them off the machine.
#
#   ./backup-books.sh
#   RCLONE_REMOTE=r2:books-backups KEEP_DAYS=30 ./backup-books.sh
#
# install-books.sh puts this in your crontab; it reads the same environment
# variables so you can try it by hand before relying on it.

set -Eeuo pipefail

BENCH_DIR="${BENCH_DIR:-$HOME/frappe-bench}"
SITE="${SITE:-books.localhost}"
KEEP_DAYS="${KEEP_DAYS:-14}"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"
BACKUP_DIR="$BENCH_DIR/sites/$SITE/private/backups"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}
say() { printf '%s %s\n' "$(date -Iseconds)" "$*"; }

[[ -d $BENCH_DIR ]] || die "no bench at $BENCH_DIR (set BENCH_DIR)"
[[ -d $BENCH_DIR/sites/$SITE ]] || die "no site $SITE in $BENCH_DIR (set SITE)"
command -v bench >/dev/null 2>&1 || export PATH="$HOME/.local/bin:$PATH"
command -v bench >/dev/null 2>&1 || die "bench is not on PATH"

cd "$BENCH_DIR"

say "backing up $SITE"
bench --site "$SITE" backup --with-files

if [[ -d $BACKUP_DIR ]]; then
  # Old databases, files and configs; keep the directory itself.
  find "$BACKUP_DIR" -type f -mtime "+$KEEP_DAYS" -print -delete
fi

if [[ -n $RCLONE_REMOTE ]]; then
  command -v rclone >/dev/null 2>&1 || die "RCLONE_REMOTE is set but rclone is not installed"
  say "copying backups to $RCLONE_REMOTE"
  rclone copy "$BACKUP_DIR" "$RCLONE_REMOTE/$SITE" --update
else
  say "RCLONE_REMOTE is unset: backups stayed on this machine"
fi

say "done"
