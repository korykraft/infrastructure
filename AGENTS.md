This is infrastructure for my homelab: an Ubuntu VM on a Windows PC. My main computer is my Mac, and Ansible runs from there to provision the VM.

- `docker/` is the live stacks directory on the VM (`~/docker` symlinks to it) and contains service data. Never `git add -f` inside it and never `git clean` it.
- Compose files are plain files, not templates. Secrets go in `.env` (never committed) and are referenced as `${VAR}`; keep `.env.example` in step.
- Do not switch this checkout on the VM to a branch or commit that lacks the stack files (e.g. an old `main`): git deletes and recreates them, which breaks the bind mounts of running containers until they are recreated. Merge without switching (`git fetch . branch:main`) or recreate the affected stacks afterwards.
- See README.md for the layout, the stack and port table, and the backups.
