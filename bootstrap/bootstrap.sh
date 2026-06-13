#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root or via sudo." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[bootstrap] Updating apt metadata"
apt-get update

echo "[bootstrap] Installing bootstrap dependencies"
apt-get install -y software-properties-common python3 python3-pip python3-venv sshpass git curl

echo "[bootstrap] Installing Ansible"
apt-get install -y ansible

echo "[bootstrap] Bootstrap complete"
echo "[bootstrap] Repository root: ${REPO_ROOT}"
echo "[bootstrap] Next step: ansible-playbook -i ansible/inventory.ini ansible/site.yml"
