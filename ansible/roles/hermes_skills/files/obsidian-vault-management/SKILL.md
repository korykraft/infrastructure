---
name: obsidian-vault-management
description: Use when creating, editing, organizing, or referencing notes in the user's Obsidian vault.
---

# Obsidian Vault Management

Use this skill whenever working with the user's Obsidian vault.

The user wants one primary vault for everything.

The vault should be organized by clear top-level areas, not by creating separate vaults.

## Vault location

Default vault path:

```text
/home/kory/workspace/vaults/main
```

If the actual vault path differs, inspect the workspace and use the existing vault instead of creating a new one.

## Core principle

The vault is for durable knowledge, plans, decisions, references, and reusable context.

It is not for random temporary scratch notes unless the user explicitly asks.

Prefer clear, boring organization.

Do not overcomplicate the vault with too many folders too early.

## Top-level structure

Use this structure:

```text
main/
├── 00 Inbox/
├── 10 PictuBook/
├── 20 Local Setup & Homelab/
├── 30 Business/
├── 40 Reference/
├── 50 People & Vendors/
├── 90 Archive/
└── Templates/
```

## Folder purposes

### 00 Inbox

Use for unprocessed notes, quick captures, rough notes, and temporary imports.

Move notes out of Inbox once they have a durable home.

### 10 PictuBook

Use for PictuBook product, app, design, infrastructure, prompts, vendors, print logistics, business planning, and launch notes.

Suggested subfolders:

```text
10 PictuBook/
├── Product/
├── Engineering/
├── Design/
├── AI & Prompts/
├── Print & Fulfillment/
├── Business/
├── Vendors/
└── Decisions/
```

### 20 Local Setup & Homelab

Use for the user's Ubuntu server, Hermes, Forgejo, Syncthing, Ansible, Docker, Mac setup, networking, and local infrastructure.

Suggested subfolders:

```text
20 Local Setup & Homelab/
├── Ansible/
├── Docker/
├── Hermes/
├── Forgejo/
├── Syncthing/
├── Networking/
├── Hardware/
└── Decisions/
```

### 30 Business

Use for general business notes that are not specific to PictuBook.

Do not store actual private legal, tax, banking, or identity documents here unless the user explicitly asks.

Actual files belong in the workspace business directory, not necessarily in the vault.

### 40 Reference

Use for reusable technical, legal, business, design, and operational references.

### 50 People & Vendors

Use for vendor summaries, contact context, service notes, and account-purpose records.

Do not store passwords, API keys, private keys, or recovery codes.

### 90 Archive

Use for inactive, old, or superseded notes.

### Templates

Use for reusable note templates.

## Note naming

Prefer descriptive names.

Examples:

```text
Forgejo Docker Setup.md
Hermes Permission Model.md
PictuBook Prompt Lab.md
Cloudflare D1 Notes.md
Syncthing Workspace Sync.md
```

Avoid vague names like:

```text
notes.md
misc.md
stuff.md
new note.md
```

## Frontmatter

Use frontmatter when it helps future filtering.

Default template:

```yaml
---
area:
status:
tags:
created:
updated:
---
```

Example:

```yaml
---
area: homelab
status: active
tags:
  - ansible
  - docker
  - forgejo
created: 2026-06-14
updated: 2026-06-14
---
```

## Decision notes

For durable decisions, use this format:

```md
# Decision Title

## Decision

What was decided.

## Reason

Why this decision was made.

## Alternatives considered

- Option A
- Option B

## Consequences

What this affects.

## Related

- Links to related notes or repo files.
```

## When to create a vault note

Create or update a vault note when:

- the user asks to remember durable project knowledge
- a decision affects future work
- a recurring setup/process should be documented
- a vendor/tool/service needs a durable summary
- a complex topic needs an organized reference
- Hermes needs reusable context for future work

Do not create vault notes for every small code edit.

## Relationship to Git repos

Repo files are the source of truth for code and operational instructions.

Vault notes are for broader context, explanation, and cross-project knowledge.

If a repo has:

```text
README.md
AGENTS.md
TASKS.md
DECISIONS.md
RUNBOOK.md
```

do not duplicate all of that into the vault.

Instead, summarize the important context and link/reference the repo path.

## Secrets rule

Never write secrets into the vault.

Do not store:

- API keys
- passwords
- private SSH keys
- recovery codes
- full `.env` files
- payment credentials

Write only references like:

```text
Secret stored outside repo in local environment file or password manager.
```

## Maintenance rule

When adding notes:

- put them in the most specific existing folder
- add links to related notes when useful
- update old notes instead of creating duplicates
- keep notes concise and useful
- move stale notes to Archive when appropriate

## Expansion rule

As the user discovers new Hermes workflows, add new top-level folders only when there is a clear recurring need.

Do not create speculative folder trees.
