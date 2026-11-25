# Homelab infrastructure

Everything needed to run and rebuild my self-hosted services.

| | |
| --- | --- |
| Server | Ubuntu VM on the Windows PC, `192.168.1.84`, user `kory` |
| Workstation | Mac, `192.168.1.201`. Ansible runs from here |
| This repo on the VM | `~/workspace/infrastructure` |
| Stacks on the VM | `~/docker` (a symlink to `docker/` in this repo) |
| Backups on the VM | `~/backups` |
| Remote | `git@github.com:korykraft/infrastructure.git` |

**Start here: http://192.168.1.84:3005** is the dashboard, with live status of
every service, the last backup, and bookmarks.

## Layout

```text
docker/     One folder per stack, each with a plain docker-compose.yml.
ansible/    Host setup, plus one `stacks` role that links ~/docker, writes
            .env files from the vault, starts stacks and installs backup timers.
scripts/    backup.sh, restore.sh, kan-backup.sh (all run on the VM)
systemd/    User timers installed on the VM for the backups
mac/        Script and launchd job that pull the backups to the Mac
```

Rules that keep this working:

- Compose files are plain files, not templates. Editing one by hand or in
  Dockge shows up here as a git diff; commit it.
- Secrets go in a `.env` next to the compose file, referenced as `${VAR}`.
  `.env` is never committed. Each stack has a `.env.example` listing the keys.
- `docker/` also holds live service data. `.gitignore` tracks only
  `docker-compose.yml`, `.env.example` and named config files there. Never
  `git add -f` or `git clean` inside `docker/`.

## Services

| Stack | URL | State | Backed up | Notes |
| --- | --- | --- | --- | --- |
| vaultwarden | http://192.168.1.84:8088 | running | yes | Password manager |
| kan | http://192.168.1.84:3006 | running | yes | Pinned to 0.6.0 |
| penpot | http://192.168.1.84:9001 | running | yes | Mail catcher on :8025 |
| mem0 | http://192.168.1.84:8888, dashboard :3001 | running | yes | Agent memory, uses Ollama. See below |
| ollama | http://192.168.1.84:11434 | running | no | Local models, CPU only. Models re-download on rebuild |
| forgejo | http://192.168.1.84:3000, ssh :222 | stopped | yes | Kept for later |
| dashboard | http://192.168.1.84:3005 | running | bookmarks | Status page and bookmarks, see below |
| dockge | http://192.168.1.84:5001 | running | no | Manages the stacks in `~/docker` |
| kanboard | http://192.168.1.84:3040 | running | no | |
| searxng | http://192.168.1.84:8080 | running | no | Stateless |
| mcp-excalidraw | http://192.168.1.84:3030 | running | no | Canvas for the Excalidraw MCP server |
| stripe, stripe/pictubook-vm | none | running | no | Webhook listeners, forward to host port 8787 |
| stripe/pictubook-local | none | stopped | no | Forwards to the Mac |

Not managed here and not backed up: the projects under `~/workspace`
(`personal-finance` on :8000, `mogg` Postgres on :5433, `fama`), Hermes, and
Syncthing (installed but stopped; its role is commented out in `site.yml`).

## Dashboard

A small Python app with no dependencies, in `docker/dashboard/`.

- **Status** comes from Docker and from an HTTP request to each service every
  few seconds. Every compose project on the VM appears automatically, in or
  out of this repo. A service is red when its containers run but its address
  does not answer, amber when some of its containers are down, grey when stopped.
- **Names, ports and health paths** are in
  `docker/dashboard/config/services.json`. Edit it to name a new stack, add a
  check for something outside Docker (`extras`), or hide a project (`hidden`).
  Changes apply within seconds.
- **Bookmarks** are added, grouped, reordered and deleted on the page itself
  and stored in `docker/dashboard/data/bookmarks.json`, which is backed up.
- It has no login, like the other services here: anyone on the home network
  can open it and edit bookmarks. It reads the Docker socket, so do not expose
  it to the internet.

## mem0 and Ollama

mem0 stores and recalls memories for agents. It needs a chat model to extract
facts and an embedding model to search them; both come from the `ollama` stack
through its OpenAI-compatible API, so nothing leaves the VM.

- Models: `qwen2.5:3b` (extraction) and `nomic-embed-text` (embeddings, 768
  dimensions). Set in `docker/mem0/.env`.
- The VM has no GPU. Recall takes a fraction of a second; storing a memory
  takes two to three minutes because extraction runs on the CPU.
- To use a faster machine, run Ollama there and change `OPENAI_BASE_URL` in
  `docker/mem0/.env`, then `docker compose up -d` in `~/docker/mem0`.
- The 768-dimension setting is not in a file: it was set once through
  `POST /configure` and is stored in mem0's database, so it comes back with a
  restore. On an empty database, set it again:

  ```bash
  curl -X POST http://localhost:8888/configure -H "X-API-Key: $ADMIN_API_KEY" -H 'Content-Type: application/json' -d '{"vector_store":{"config":{"embedding_model_dims":768,"collection_name":"memories_768"}},"embedder":{"config":{"embedding_dims":768}}}'
  ```

- API access uses `ADMIN_API_KEY` from `docker/mem0/.env` in an `X-API-Key`
  header. The web dashboard on :3001 asks you to create an admin login the
  first time you open it.
- mem0 builds from `docker/mem0/source`, a checkout of the upstream repo pinned
  in `ansible/roles/stacks/defaults/main.yml`.

## Day to day

Change a stack on the VM, then commit:

```bash
cd ~/docker/kan && docker compose up -d
cd ~/workspace/infrastructure && git add -A docker && git commit
```

Add a stack: create `docker/<name>/docker-compose.yml`, put secrets in
`docker/<name>/.env`, add a `.env.example`, and add the name to
`stacks_running` in `ansible/roles/stacks/defaults/main.yml`. If it holds data
worth keeping, add a `backup_<name>` and `restore_<name>` to the scripts.

Run Ansible from the Mac:

```bash
just play                  # everything
just play --tags stacks    # only the docker stacks
just play --tags base      # one host role
```

## Backups

Two timers run on the VM as systemd user units. Both catch up at next boot if
the VM was off.

| When | What | Where |
| --- | --- | --- |
| 03:15 | `scripts/kan-backup.sh`: Kan database as plain SQL, committed to git when it changed. Gives a diffable history of the boards | `~/backups/kan` |
| 03:30 | `scripts/backup.sh`: Vaultwarden, Kan, Penpot, mem0 and Forgejo data, dashboard bookmarks, plus every stack's `.env`. Keeps the last 14 | `~/backups/homelab/<date>` |

```bash
just backup                                  # back up now
just kan-backup                              # Kan snapshot now
systemctl --user list-timers '*backup*'      # next runs
systemctl --user status homelab-backup       # last result
git -C ~/backups/kan log --stat              # Kan history
```

What each backup folder contains:

```text
env.tar.gz                  every stack's .env
vaultwarden/data.tar.gz     data folder with a consistent copy of the database
kan/kan_db.sql.gz
penpot/penpot.sql.gz        database
penpot/assets.tar.gz        uploaded files
mem0/*.sql.gz, history.tar.gz
forgejo/forgejo.tar.gz      repos, database and config
dashboard/bookmarks.json
MANIFEST.sha256             checksums, verified before any restore
```

Backups are not encrypted and contain secrets and password hashes. The
Vaultwarden vault inside is still encrypted with its master password.

### Off-VM copy on the Mac

`~/backups` on the VM does not survive losing the VM. The Mac pulls it:

```bash
mac/pull-backups.sh        # mirrors to ~/Backups/homelab-vm on the Mac
```

To run it daily at 10:00, on the Mac, from this repo:

```bash
cp mac/pull-backups.sh ~/Backups/pull-backups.sh
cp mac/com.homelab.pull-backups.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.homelab.pull-backups.plist
```

`~/Backups/homelab-vm/.last-pull` shows when it last succeeded.

## Restore one service

On the VM. This replaces that service's current data.

```bash
scripts/restore.sh ~/backups/homelab/latest kan --yes
```

Services: `kan`, `penpot`, `mem0`, `vaultwarden`, `forgejo`, `dashboard`, `env`, or `all`.

To roll Kan back to an older board state instead, follow
`~/backups/kan/README.md`.

## Rebuild the VM from nothing

1. Create an Ubuntu VM. Create user `kory` with sudo and enable SSH from the Mac.
2. Add an SSH key from the new VM to GitHub, so it can clone this repo.
3. On the Mac, set the VM's IP in `ansible/inventory.ini` (and in
   `mac/pull-backups.sh` if it changed).
4. Copy the newest backup from the Mac to the VM:

   ```bash
   rsync -a ~/Backups/homelab-vm/ kory@192.168.1.84:backups/
   ```

5. On the Mac, set up the host and clone the repo onto the VM. The stacks
   cannot start yet because their `.env` files are missing, so this run stops
   at "Start stacks"; that is expected.

   ```bash
   just play
   ```

6. On the VM, put the `.env` files back, then finish from the Mac:

   ```bash
   ~/workspace/infrastructure/scripts/restore.sh ~/backups/homelab/latest env --yes
   ```

   ```bash
   just play --tags stacks
   ```

7. On the VM, restore the data:

   ```bash
   ~/workspace/infrastructure/scripts/restore.sh ~/backups/homelab/latest all --yes
   ```

8. Start Forgejo if wanted: `cd ~/docker/forgejo && docker compose up -d`.

What a rebuild does not bring back: Dockge settings, Kanboard data, the
projects under `~/workspace`, Hermes config, and Syncthing pairing.

## Secrets

- `ansible/group_vars/all/vault.yml` is encrypted; `just play` asks for the
  vault password. It holds the mem0, searxng and Stripe values.
- Kan, Penpot and the root `stripe` stack have `.env` files that exist only on
  the VM and in the backups (`env.tar.gz`).
- Keep the vault password and the Vaultwarden master password somewhere that
  is not this VM.
- The mem0 `.env` in the vault template has no `ADMIN_API_KEY` or `JWT_SECRET`
  values unless you add `mem0_admin_api_key` and `mem0_jwt_secret` to the vault;
  the real ones are in the backups.
