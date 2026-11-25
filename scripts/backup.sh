#!/usr/bin/env bash
# Back up the data of the services that matter (vaultwarden, kan, penpot, mem0,
# forgejo), the dashboard's bookmarks, and every stack's .env into one dated folder under ~/backups/homelab.
# The Mac pulls ~/backups with mac/pull-backups.sh, which is the off-VM copy.
#
# Backups are not encrypted and include secrets: the folder is mode 700.
set -uo pipefail
umask 077

ROOT="${HOMELAB_BACKUP_DIR:-$HOME/backups/homelab}"
KEEP="${HOMELAB_BACKUP_KEEP:-14}"
DOCKER_DIR="$(readlink -f "${DOCKER_DIR:-$HOME/docker}")"
HELPER_IMAGE="alpine:3"

stamp="$(date +%Y-%m-%d_%H%M%S)"
work="$ROOT/.partial-$stamp"
failed=()

mkdir -p "$work"
chmod 700 "$ROOT"
trap 'rm -rf "$work"' EXIT

log() { echo "backup: $*"; }
running() { [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]; }

# pg_dump <container> <user> <db> <output.sql.gz>
pg_dump_to() {
  local container="$1" user="$2" db="$3" out="$4"
  running "$container" || { echo "container $container is not running" >&2; return 1; }
  docker exec "$container" pg_dump -U "$user" -d "$db" --clean --if-exists --no-owner --no-privileges \
    | gzip > "$out" || return 1
  [[ "${PIPESTATUS[0]}" -eq 0 ]] || return 1
  zcat "$out" | tail -n 5 | grep -q 'PostgreSQL database dump complete'
}

# tar_path <host dir or volume name> <output.tar.gz> [tar args...]
# Runs tar in a helper container because the data is owned by root.
tar_path() {
  local src="$1" out="$2"; shift 2
  docker run --rm -v "$src":/src:ro "$HELPER_IMAGE" tar -czf - -C /src "$@" . > "$out" || return 1
  gzip -t "$out"
}

backup_kan() {
  mkdir -p "$work/kan"
  pg_dump_to kan-db kan kan_db "$work/kan/kan_db.sql.gz"
}

backup_penpot() {
  mkdir -p "$work/penpot"
  pg_dump_to penpot-penpot-postgres-1 penpot penpot "$work/penpot/penpot.sql.gz" || return 1
  tar_path penpot_penpot_assets "$work/penpot/assets.tar.gz"
}

backup_mem0() {
  mkdir -p "$work/mem0"
  pg_dump_to mem0-postgres postgres postgres "$work/mem0/postgres.sql.gz" || return 1
  pg_dump_to mem0-postgres postgres mem0_app "$work/mem0/mem0_app.sql.gz" || return 1
  tar_path "$DOCKER_DIR/mem0/history" "$work/mem0/history.tar.gz"
}

backup_vaultwarden() {
  mkdir -p "$work/vaultwarden"
  local data="$DOCKER_DIR/vaultwarden/data"
  if running vaultwarden; then
    # Ask Vaultwarden for a consistent copy of its SQLite database, then pack
    # the data folder with that copy in place of the live db files.
    docker exec vaultwarden /vaultwarden backup >/dev/null || return 1
    docker run --rm -v "$data":/src "$HELPER_IMAGE" sh -ec '
      snap="$(ls -t /src/db_*.sqlite3 | head -n 1)"
      mkdir /out
      tar -cf - -C /src --exclude=./icon_cache --exclude=./tmp \
        --exclude="./db.sqlite3*" --exclude="./db_*.sqlite3" . | tar -xf - -C /out
      cp "$snap" /out/db.sqlite3
      rm -f /src/db_*.sqlite3
      tar -czf - -C /out .' > "$work/vaultwarden/data.tar.gz" || return 1
    gzip -t "$work/vaultwarden/data.tar.gz"
  else
    tar_path "$data" "$work/vaultwarden/data.tar.gz" --exclude=./icon_cache --exclude=./tmp
  fi
}

backup_forgejo() {
  mkdir -p "$work/forgejo"
  running forgejo && log "forgejo is running; its SQLite database is copied live"
  tar_path "$DOCKER_DIR/forgejo/forgejo" "$work/forgejo/forgejo.tar.gz"
}

backup_dashboard() {
  mkdir -p "$work/dashboard"
  local f
  # A missing file just means nothing has been added on the page yet.
  for f in bookmarks.json service-groups.json; do
    [[ -f "$DOCKER_DIR/dashboard/data/$f" ]] && cp "$DOCKER_DIR/dashboard/data/$f" "$work/dashboard/$f"
  done
  return 0
}

backup_env() {
  # Every stack's .env, so a rebuild does not depend on the Ansible vault.
  ( cd "$DOCKER_DIR" && find . -maxdepth 3 -name .env \
      -not -path './mem0/source/*' -not -path './forgejo/forgejo/*' -print0 \
      | tar -czf "$work/env.tar.gz" --null -T - )
}

for service in env kan penpot mem0 vaultwarden forgejo dashboard; do
  if "backup_$service"; then
    log "$service ok"
  else
    log "$service FAILED"
    failed+=("$service")
  fi
done

( cd "$work" && find . -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum > MANIFEST.sha256 )

if (( ${#failed[@]} )); then
  printf '%s\n' "${failed[@]}" > "$work/FAILED"
fi
mv "$work" "$ROOT/$stamp"
trap - EXIT

if (( ${#failed[@]} )); then
  log "incomplete backup kept at $ROOT/$stamp (failed: ${failed[*]})"
  exit 1
fi

ln -sfn "$stamp" "$ROOT/latest"
# Keep the newest $KEEP complete backups.
find "$ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' | sort | head -n "-$KEEP" | while read -r old; do
  rm -rf "$old"
done
log "done: $ROOT/$stamp ($(du -sh "$ROOT/$stamp" | cut -f1))"
