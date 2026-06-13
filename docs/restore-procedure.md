# Restore Procedure

## Goal

Rebuild a fresh Ubuntu Server host from Git, then restore only the required persistent data.

## Steps

1. Install Ubuntu Server LTS on the target machine.
2. Ensure SSH access works from the Mac Mini or other admin workstation.
3. Clone this repository onto the server.
4. Run `sudo ./bootstrap/bootstrap.sh`.
5. Update `ansible/inventory.ini` and `ansible/group_vars/all.yml` for the real host.
6. Run `./scripts/install.sh` or `ansible-playbook -i ansible/inventory.ini ansible/site.yml`.
7. Copy service `.env.example` files to `.env` and provide real values.
8. Restore Forgejo data with `scripts/restore.sh /path/to/archive.tar.gz`.
9. Start the Forgejo stack from `docker/forgejo/`.
10. Validate application access, SSH cloning, and data integrity.

## Validation Checklist

- SSH is reachable
- Docker is installed and running
- Syncthing is installed
- Required host directories exist under `/opt/homelab`
- Forgejo starts successfully
- Forgejo repositories and metadata are present after restore

## Notes

- Restore persistent data only after the base filesystem layout exists.
- If ownership mismatches occur, correct them before starting containers.
- Extend this process later for n8n and future AI-related persistent storage.
