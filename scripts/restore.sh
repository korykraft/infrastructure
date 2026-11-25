#!/usr/bin/env bash
# Restore service data from a backup made by scripts/backup.sh.
# This REPLACES the current data of the service you name.
#
#   scripts/restore.sh <backup dir> <env|kan|penpot|mem0|vaultwarden|forgejo|dashboard|all> --yes
#
# On a fresh VM: restore `env` first, start the stacks, then restore `all`.
set -euo pipefail

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[[ $# -eq 3 && "$3" == "--yes" ]] || usage
SRC="$(readlink -f "$1")"; WHAT="$2"
[[ -d "$SRC" ]] || { echo "no such backup: $1" >&2; exit 1; }
DOCKER_DIR="$(readlink -f "${DOCKER_DIR:-$HOME/docker}")"
HELPER_IMAGE="alpine:3"

log() { echo "restore: $*"; }
need() { [[ -f "$SRC/$1" ]] || { echo "missing in backup: $1" >&2; exit 1; }; }
compose() { ( cd "$DOCKER_DIR/$1" && shift && docker compose "$@" ); }
# psql_load <container> <user> <db> <dump.sql.gz>
psql_load() { zcat "$4" | docker exec -i "$1" psql -q -v ON_ERROR_STOP=1 -U "$2" -d "$3" >/dev/null; }
# untar_into <host dir or volume name> <archive.tar.gz>: empty the target, then unpack.
untar_into() {
  docker run --rm -i -v "$1":/dst "$HELPER_IMAGE" sh -ec \
    'find /dst -mindepth 1 -maxdepth 1 -exec rm -rf {} +; tar -xzf - -C /dst' < "$2"
}

( cd "$SRC" && sha256sum --quiet -c MANIFEST.sha256 ) || { echo "backup failed its checksum" >&2; exit 1; }

restore_env() {
  need env.tar.gz
  tar -xzf "$SRC/env.tar.gz" -C "$DOCKER_DIR"
}

restore_kan() {
  need kan/kan_db.sql.gz
  compose kan up -d postgres
  compose kan stop web
  psql_load kan-db kan kan_db "$SRC/kan/kan_db.sql.gz"
  compose kan up -d
}

restore_penpot() {
  need penpot/penpot.sql.gz; need penpot/assets.tar.gz
  compose penpot up -d penpot-postgres
  compose penpot stop penpot-frontend penpot-backend penpot-exporter penpot-admin-console
  psql_load penpot-penpot-postgres-1 penpot penpot "$SRC/penpot/penpot.sql.gz"
  untar_into penpot_penpot_assets "$SRC/penpot/assets.tar.gz"
  compose penpot up -d
}

restore_mem0() {
  need mem0/postgres.sql.gz; need mem0/mem0_app.sql.gz; need mem0/history.tar.gz
  compose mem0 up -d postgres
  compose mem0 stop mem0 mem0-dashboard
  docker exec mem0-postgres psql -U postgres -Atc "select 1 from pg_database where datname='mem0_app'" | grep -q 1 \
    || docker exec mem0-postgres createdb -U postgres mem0_app
  psql_load mem0-postgres postgres postgres "$SRC/mem0/postgres.sql.gz"
  psql_load mem0-postgres postgres mem0_app "$SRC/mem0/mem0_app.sql.gz"
  untar_into "$DOCKER_DIR/mem0/history" "$SRC/mem0/history.tar.gz"
  compose mem0 up -d
}

restore_vaultwarden() {
  need vaultwarden/data.tar.gz
  compose vaultwarden stop
  mkdir -p "$DOCKER_DIR/vaultwarden/data"
  untar_into "$DOCKER_DIR/vaultwarden/data" "$SRC/vaultwarden/data.tar.gz"
  compose vaultwarden up -d
}

restore_forgejo() {
  need forgejo/forgejo.tar.gz
  local was_running; was_running="$(docker inspect -f '{{.State.Running}}' forgejo 2>/dev/null || true)"
  [[ "$was_running" == "true" ]] && compose forgejo stop
  mkdir -p "$DOCKER_DIR/forgejo/forgejo"
  untar_into "$DOCKER_DIR/forgejo/forgejo" "$SRC/forgejo/forgejo.tar.gz"
  [[ "$was_running" == "true" ]] && compose forgejo up -d
  return 0
}

restore_dashboard() {
  [[ -f "$SRC/dashboard/bookmarks.json" ]] || { log "no bookmarks in this backup"; return 0; }
  mkdir -p "$DOCKER_DIR/dashboard/data"
  cp "$SRC/dashboard/bookmarks.json" "$DOCKER_DIR/dashboard/data/bookmarks.json"
}

case "$WHAT" in
  env|kan|penpot|mem0|vaultwarden|forgejo|dashboard) "restore_$WHAT"; log "$WHAT restored" ;;
  all) for s in kan penpot mem0 vaultwarden forgejo dashboard; do "restore_$s"; log "$s restored"; done ;;
  *) usage ;;
esac
