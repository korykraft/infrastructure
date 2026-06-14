---
name: repo-stewardship
description: Use when working in any Git repository. Maintains README.md, AGENTS.md, TASKS.md, DECISIONS.md, and RUNBOOK.md as auditable project context.
---

# Repo Stewardship Skill

Use this skill whenever working in any Git repository.

The goal is to keep project context, agent instructions, task state, decisions, and operational runbooks auditable in Git.

## Standard repo context files

Prefer these files at the repository root:

```text
README.md
AGENTS.md
TASKS.md
DECISIONS.md
RUNBOOK.md
```

If the repository already uses different equivalent files, respect the existing convention.

## File purposes

### README.md

Public or high-level project overview.

Use for:

- what the repo is
- how to install/run/test
- important architecture overview
- links to deeper docs

Do not use for:

- long task logs
- temporary notes
- secrets

### AGENTS.md

Instructions for coding agents.

Use for:

- repo-specific rules
- allowed commands
- test commands
- safety constraints
- file organization rules
- branch/PR workflow
- what not to touch

Do not use for:

- task history
- decision history
- secrets

### TASKS.md

Current work state.

Use for:

- active tasks
- backlog
- blocked items
- next actions
- acceptance criteria

Keep it current. Remove or mark completed stale items.

### DECISIONS.md

Durable decision log.

Use for meaningful decisions and infrastructure/product/code architecture changes.

Append new entries near the top.

Use this format:

```md
## YYYY-MM-DD — Short title

Summary:
- What changed.

Reason:
- Why this choice was made.

Changed files:
- path/to/file
- path/to/file

Validation:
- Command run:
  ```bash
  command here
  ```
- Result:
  - What passed or failed.

Rollback:
- How to undo or revert this decision.

Notes:
- Assumptions, caveats, or follow-up work.
```

Log a decision when:

- adding or changing infrastructure
- adding or changing services
- changing database schema
- changing authentication/authorization
- changing deployment behavior
- changing agent/Hermes behavior
- changing persistent data handling
- making a non-obvious architecture choice
- choosing one tool/library/provider over another

Do not log every tiny edit.

### RUNBOOK.md

Operational instructions.

Use for:

- deploy commands
- restore steps
- backup steps
- debugging procedures
- service restart commands
- common failure recovery

Should be practical and command-oriented.

## When finishing a task

Before finishing any meaningful task:

1. Run `git status`.
2. Review changed files.
3. Update `TASKS.md` if task state changed.
4. Update `DECISIONS.md` if a meaningful decision was made.
5. Update `RUNBOOK.md` if operations, deployment, backup, restore, or debugging steps changed.
6. Update `AGENTS.md` if agent instructions changed.
7. Update `README.md` if user-facing setup or project overview changed.

## Safety rules

Never write secrets to these files.

Do not include:

- API keys
- tokens
- passwords
- private keys
- full `.env` contents
- sensitive personal data

If a secret is relevant, write only:

```text
Stored outside repo in the appropriate secret manager or local env file.
```

## Validation rule

When possible, include validation commands and results.

Examples:

```bash
pnpm test
pnpm typecheck
docker compose ps
ansible-playbook -i ansible/inventory-test.ini ansible/site.yml --check
```

If validation was not run, explicitly write:

```text
Validation: Not run
Reason: <short reason>
```

## Existing conventions win

If a repo already has:

- docs/decisions.md
- docs/runbook.md
- .cursor/rules
- CLAUDE.md
- AGENTS.md
- CONTRIBUTING.md

then follow the existing convention instead of duplicating conflicting files.

Prefer adding cross-links rather than creating redundant docs.

## Minimalism rule

Keep the files useful.

Do not create huge generic documents.

Prefer short, specific, current entries.

Delete or archive stale task notes when appropriate.
