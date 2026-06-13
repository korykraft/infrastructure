#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/forgejo-backup.tar.gz" >&2
  exit 1
fi

ARCHIVE_PATH="$1"
FORGEJO_DATA_DIR="${FORGEJO_DATA_DIR:-/opt/homelab/data/forgejo}"

if [[ ! -f "${ARCHIVE_PATH}" ]]; then
  echo "Backup archive not found: ${ARCHIVE_PATH}" >&2
  exit 1
fi

mkdir -p "${FORGEJO_DATA_DIR}"

echo "[restore] Restoring Forgejo data into ${FORGEJO_DATA_DIR}"
tar -xzf "${ARCHIVE_PATH}" -C "${FORGEJO_DATA_DIR}"

echo "[restore] Restore complete"
echo "[restore] Verify ownership and then start the Forgejo stack"
