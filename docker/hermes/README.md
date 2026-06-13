# Hermes Stack

This is a starter Docker Compose definition for Hermes.

## Required Host Directories

- `/opt/homelab/data/hermes`

## Setup

1. Copy `.env.example` to `.env`.
2. Replace the placeholder image if your Hermes deployment uses a different source.
3. Confirm the application data path is correct for your runtime.
4. Start the service with `docker compose up -d`.

## Notes

- The image reference is intentionally a placeholder starter value.
- Adjust ports, environment variables, and storage once the real deployment details are finalized.
