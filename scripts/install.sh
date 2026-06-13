#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "ansible-playbook is not installed. Run bootstrap/bootstrap.sh on the server first." >&2
  exit 1
fi

echo "[install] Using repository at ${REPO_ROOT}"
echo "[install] Running Ansible playbook"
ansible-playbook -i "${REPO_ROOT}/ansible/inventory.ini" "${REPO_ROOT}/ansible/site.yml"

echo "[install] Base provisioning complete"
echo "[install] Next: configure .env files and start Docker Compose stacks"
