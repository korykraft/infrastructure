#!/usr/bin/env bash
# Dump the Kan database to a plain-text SQL file and commit it to a local git
# repo, so every change to the boards has a dated, diffable, restorable snapshot.
#
# The dump contains user accounts and password hashes. The backup repo is
# local-only; do not push it anywhere public.
set -euo pipefail

BACKUP_DIR="${KAN_BACKUP_DIR:-$HOME/backups/kan}"
CONTAINER="${KAN_DB_CONTAINER:-kan-db}"
DB_USER="${KAN_DB_USER:-kan}"
DB_NAME="${KAN_DB_NAME:-kan_db}"
DUMP_FILE="kan_db.sql"

if [[ ! -d "$BACKUP_DIR/.git" ]]; then
  mkdir -p "$BACKUP_DIR"
  chmod 700 "$BACKUP_DIR"
  git -C "$BACKUP_DIR" init -q -b main
  cat > "$BACKUP_DIR/README.md" <<'README'
# Kan database snapshots

`kan_db.sql` is a full `pg_dump` of the Kan database, committed by
`infrastructure/scripts/kan-backup.sh` whenever the data has changed.
It contains user accounts and password hashes: keep this repo private.

## Look at history

    git log --stat
    git diff HEAD~1 -- kan_db.sql

## Restore a snapshot

    git checkout <commit> -- kan_db.sql
    docker stop kan-web
    docker exec kan-db psql -U kan -d kan_db -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
    docker exec -i kan-db psql -U kan -d kan_db < kan_db.sql
    docker start kan-web
    git checkout main -- kan_db.sql
README
  git -C "$BACKUP_DIR" add README.md
fi

# Dump to a temp file first so a failed dump never replaces a good one.
tmp="$(mktemp "$BACKUP_DIR/.dump.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
docker exec "$CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges > "$tmp"
if ! grep -q 'PostgreSQL database dump complete' "$tmp"; then
  echo "kan-backup: dump is incomplete, keeping the previous snapshot" >&2
  exit 1
fi
mv "$tmp" "$BACKUP_DIR/$DUMP_FILE"
chmod 600 "$BACKUP_DIR/$DUMP_FILE"

cd "$BACKUP_DIR"
git add -A
# pg_dump writes a random \restrict token on every run; ignore it so an
# unchanged database does not produce a commit.
if git rev-parse -q --verify HEAD >/dev/null \
   && git diff --cached --quiet -I '^\\(un)?restrict ' HEAD --; then
  git reset -q --hard HEAD
  echo "kan-backup: no changes"
  exit 0
fi
git -c user.name="kan-backup" -c user.email="kan-backup@localhost" \
  commit -q -m "Kan snapshot $(date '+%Y-%m-%d %H:%M')"
echo "kan-backup: committed $(git rev-parse --short HEAD)"
