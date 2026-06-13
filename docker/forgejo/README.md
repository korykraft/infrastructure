# Forgejo Stack

This directory contains the starter Docker Compose configuration for Forgejo.

## Required Host Directories

- `/opt/homelab/data/forgejo`

## Setup

1. Copy `.env.example` to `.env`.
2. Adjust ports and paths for the target server.
3. Ensure the bind mount directory exists.
4. Start the stack with `docker compose up -d` from this directory.

## Notes

- `/data` is the primary persistent directory.
- Back up the host path mapped to `FORGEJO_DATA_DIR`.
- Real application secrets should be set in `.env`, not committed.
