# Homelab Architecture

This document describes the current target architecture for the homelab environment and the assumptions behind the repository layout.

## Overview

- Primary workstation: Mac Mini
- Target host: dedicated Ubuntu Server LTS machine
- Configuration management: Ansible
- Service runtime: Docker Engine with Docker Compose plugin
- File synchronization: Syncthing
- Source of truth: this Git repository

## System Roles

### Mac Mini

- Primary workstation for editing infrastructure code and documentation
- Launch point for Ansible runs and administrative access
- Local working copy of the infrastructure repository

### Dedicated Ubuntu Server

- Runs all homelab services
- Hosts Docker containers and persistent bind mounts
- Serves as the long-lived replacement for the prior Ubuntu VM

### Syncthing

- Synchronizes selected working directories between machines
- Useful for operational convenience, but not a replacement for backups
- Should not be treated as the system of record for infrastructure

### Forgejo

- Self-hosted Git service for source control and internal collaboration
- Expected to be the primary persistent application data set
- Should receive the highest backup priority among current services

### Hermes

- Additional application service deployed through Docker Compose
- Environment-specific configuration should remain externalized in `.env`
- Persistent requirements depend on the service's final runtime design

### n8n

- Workflow automation service
- May become a future persistent data source if workflows or credentials are stored locally
- Should be planned for backup once moved into regular use

### Future AI Services

- Likely to require significant disk for models and caches
- Model artifacts may be re-downloadable, but local fine-tuned assets may not be
- Keep model storage paths clearly separated from core infrastructure files

## Networking Assumptions

- The Ubuntu server has a stable LAN address or DHCP reservation
- SSH access is enabled for remote administration
- Internal services are initially LAN-scoped unless intentionally exposed
- Firewall rules will begin with a conservative baseline and be tightened as services mature

## Service Layout

```text
Mac Mini
  |
  | ssh / git / ansible
  v
Ubuntu Server
  |
  +-- /opt/homelab/apps/forgejo      -> docker compose stack
  +-- /opt/homelab/apps/hermes       -> docker compose stack
  +-- /opt/homelab/apps/n8n          -> docker compose stack
  +-- /opt/homelab/data/forgejo      -> persistent bind mount
  +-- /opt/homelab/data/n8n          -> future persistent bind mount
  +-- /opt/homelab/backups           -> local backup staging
  +-- Syncthing                      -> selected synchronization paths
```

## Logical Flow

```text
Git Repository
  -> bootstrap script installs Ansible prerequisites
  -> Ansible configures base packages, Docker, directories, Syncthing
  -> service-specific compose stacks are deployed manually or by future automation
  -> persistent data is restored into bind mounts
  -> services start and resume operation
```

## Architecture Diagram

```text
+-------------------+              +--------------------------------+
| Mac Mini          |              | Dedicated Ubuntu Server        |
|-------------------|              |--------------------------------|
| Git working copy  | -- SSH -->   | Ansible-managed base OS        |
| Ansible control   | -- Git -->   | Docker Engine                  |
| Docs/scripts      |              | Compose stacks                 |
+-------------------+              | Forgejo / Hermes / n8n         |
                                   | Syncthing                      |
                                   | Persistent bind mount data     |
                                   +--------------------------------+
```

## Operational Boundaries

- Infrastructure definitions belong in Git.
- Secrets do not belong in Git.
- Service data lives outside the repository in dedicated host directories.
- Backups cover persistent data plus this repository.
