# Homelab Infrastructure

This repository defines the reproducible infrastructure for a dedicated Ubuntu Server homelab machine. The goal is to rebuild the server from Git with minimal manual steps and keep only true service data outside the repository.

## Purpose

- Store infrastructure, configuration, provisioning, service definitions, scripts, and documentation in Git.
- Make server rebuilds predictable on new Ubuntu Server LTS hardware.
- Separate replaceable infrastructure from persistent application data.

## Design Philosophy

- Treat the server as Infrastructure as Code.
- Recreate anything that can be recreated.
- Back up only persistent service data and this repository.
- Prefer simple, inspectable tooling: shell scripts, Ansible, Docker Compose, and Markdown documentation.

## Directory Structure

```text
infra/
├── README.md
├── ARCHITECTURE.md
├── ROADMAP.md
├── bootstrap/
│   └── bootstrap.sh
├── ansible/
│   ├── ansible.cfg
│   ├── inventory.ini
│   ├── site.yml
│   ├── group_vars/
│   │   └── all.yml
│   └── roles/
│       ├── base/
│       │   └── tasks/main.yml
│       ├── common/
│       │   └── tasks/main.yml
│       ├── docker/
│       │   └── tasks/main.yml
│       └── syncthing/
│           └── tasks/main.yml
├── docker/
│   ├── forgejo/
│   │   ├── .env.example
│   │   ├── README.md
│   │   └── docker-compose.yml
│   ├── hermes/
│   │   ├── .env.example
│   │   ├── README.md
│   │   └── docker-compose.yml
│   ├── n8n/
│   │   ├── .env.example
│   │   ├── README.md
│   │   └── docker-compose.yml
│   └── shared/
├── docs/
│   ├── backup-strategy.md
│   ├── migration-plan.md
│   ├── networking.md
│   └── restore-procedure.md
├── scripts/
│   ├── backup.sh
│   ├── install.sh
│   └── restore.sh
└── .gitignore
```

## Rebuild Process

1. Install Ubuntu Server LTS on the target machine.
2. Clone this repository onto the server.
3. Run `bootstrap/bootstrap.sh` to install the minimum dependencies.
4. Update `ansible/inventory.ini` and `ansible/group_vars/all.yml` for the target host.
5. Run `ansible-playbook -i ansible/inventory.ini ansible/site.yml`.
6. Copy `.env.example` files to `.env` and set real values for each service.
7. Start required services with Docker Compose.
8. Restore persistent service data where needed, primarily Forgejo.

## Backup Philosophy

- Infrastructure backup: this entire Git repository.
- Primary persistent data backup: Forgejo bind-mounted data directory.
- Additional future persistent backups: `n8n` state, AI model storage, and any databases introduced later.
- Avoid backing up ephemeral containers, images, and easily reproducible configs.

## Restore Process

1. Rebuild the base server from this repository.
2. Restore persistent data directories from backup archives.
3. Recreate runtime configuration files from examples.
4. Start Docker services and verify application health.

See `docs/restore-procedure.md` for the step-by-step flow.

## Future Expansion

- Monitoring and alerting
- Automated off-host backups
- Reverse proxy and TLS automation
- Local AI model hosting
- Additional internal services and automation workloads

## Notes

- This repository uses starter values and placeholders, not production secrets.
- Bind mount paths and hostnames are intentionally configurable through Ansible variables and `.env` files.
