# n8n Stack

This directory contains a starter n8n Compose configuration.

## Required Host Directories

- `/opt/homelab/data/n8n`

## Setup

1. Copy `.env.example` to `.env`.
2. Set the real host, protocol, and webhook values.
3. Ensure the persistent data directory exists.
4. Start the stack with `docker compose up -d`.

## Notes

- The `/home/node/.n8n` bind mount should be treated as persistent once workflows are in use.
- Include this directory in backups when n8n becomes part of production usage.
