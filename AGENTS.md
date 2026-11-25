This is infrastructure for my homelab: an Ubuntu VM on a Windows PC. My main computer is my Mac, and Ansible runs from there to provision the VM.

- `docker/` is the live stacks directory on the VM (`~/docker` symlinks to it) and contains service data. Never `git add -f` inside it and never `git clean` it.
- Compose files are plain files, not templates. Secrets go in `.env` (never committed) and are referenced as `${VAR}`; keep `.env.example` in step.
- See README.md for the layout, the stack and port table, and the backups.
