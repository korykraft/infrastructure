# Homelab Roadmap

## Phase 1

- Install and standardize the base Ubuntu Server LTS host
- Configure SSH access and baseline administration tooling
- Install Docker Engine and Docker Compose plugin
- Install and validate Syncthing for machine-to-machine synchronization
- Deploy Forgejo with bind-mounted persistent storage

## Phase 2

- Add Hermes deployment and service-specific operational notes
- Add n8n deployment and persistent backup rules
- Introduce a reverse proxy strategy for internal service routing
- Improve firewall rules based on actual service exposure

## Phase 3

- Add monitoring, metrics, and log aggregation
- Implement automated and off-host backups
- Add service health verification scripts
- Document disaster recovery validation steps

## Phase 4

- Add local AI model hosting support
- Separate model storage from application data paths
- Plan GPU or acceleration support if future hardware requires it
- Evaluate additional self-hosted services as stable infrastructure modules
