#!/bin/bash
# Run on the Mac. Mirrors the VM's ~/backups (service data backups and the Kan
# snapshot repo) to this Mac, which is the copy that survives losing the VM.
set -euo pipefail

VM="${HOMELAB_VM:-kory@192.168.1.84}"
DEST="${HOMELAB_BACKUP_DEST:-$HOME/Backups/homelab-vm}"

mkdir -p "$DEST"
chmod 700 "$DEST"
# --delete keeps the Mac in step with the VM's 14-backup retention.
rsync -a --delete "$VM:backups/" "$DEST/"
date '+%Y-%m-%d %H:%M:%S' > "$DEST/.last-pull"
echo "pulled to $DEST: $(ls "$DEST/homelab" | grep -c '^20') backups, newest $(readlink "$DEST/homelab/latest")"
