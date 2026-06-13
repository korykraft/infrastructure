# Backup Strategy

## Principles

- Back up source-controlled infrastructure through Git.
- Back up only data that cannot be reconstructed from this repository.
- Keep persistent application data in clearly named host directories.

## Current Backup Scope

### Infrastructure

- Entire `infra/` repository
- Recommended protection method: push to a remote Git forge and clone to the Mac Mini

### Persistent Data

- `/opt/homelab/data/forgejo`

### Future Persistent Data

- `/opt/homelab/data/n8n`
- AI model or fine-tuned asset directories
- Any future database volumes introduced by new services

## Not Worth Backing Up

- Docker images
- Containers
- Reproducible Compose files
- Ansible-managed package installation state
- Temporary caches and logs unless they become operationally important

## Suggested Backup Pattern

1. Keep this repository replicated to a remote Git host.
2. Create periodic archives of Forgejo data.
3. Copy backup archives off the Ubuntu server.
4. Periodically test a restore onto a non-production machine.

## Current Script Support

- `scripts/backup.sh` creates a timestamped archive of the Forgejo data directory.
- Extend this script later as more services gain persistent state.
