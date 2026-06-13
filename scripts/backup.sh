#!/usr/bin/env bash

set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/opt/homelab/backups}"
FORGEJO_DATA_DIR="${FORGEJO_DATA_DIR:-/opt/homelab/data/forgejo}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_PATH="${BACKUP_ROOT}/forgejo-data-${TIMESTAMP}.tar.gz"

mkdir -p "${BACKUP_ROOT}"

if [[ ! -d "${FORGEJO_DATA_DIR}" ]]; then
  echo "Forgejo data directory not found: ${FORGEJO_DATA_DIR}" >&2
  exit 1
fi

echo "[backup] Creating Forgejo backup archive"
tar -czf "${ARCHIVE_PATH}" -C "${FORGEJO_DATA_DIR}" .

echo "[backup] Archive created: ${ARCHIVE_PATH}"
echo "[backup] Back up this repository separately through Git remote replication"
