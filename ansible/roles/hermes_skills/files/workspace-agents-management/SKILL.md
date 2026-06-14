# Suggested structure

workspace/
├── projects/
├── business/
├── vaults/
├── infrastructure/
└── agents/
    ├── README.md
    ├── skills-source/
    ├── workflows/
    └── templates/

# Suggested Hermes skill file

File:
workspace/agents/skills-source/workspace-agents-management/SKILL.md

Contents:

---
name: workspace-agents-management
description: Use when creating, organizing, documenting, or maintaining shared agent resources in the user's workspace/agents directory.
---

# Workspace Agents Management

Use this skill whenever working with:

/workspace/agents

The purpose of this directory is to store reusable agent knowledge and operating procedures that can be shared across projects, repositories, and AI tools.

This directory is the source of truth for reusable agent assets.

Do not store runtime state here.

Do not store secrets here.

Do not store project-specific code here.

## Directory Structure

Use this structure:

agents/
├── README.md
├── skills-source/
├── workflows/
└── templates/

## Folder Definitions

### skills-source

Contains source-controlled Hermes skills.

Each skill should live in its own directory:

skills-source/
├── repo-stewardship/
│   └── SKILL.md
├── obsidian-vault-management/
│   └── SKILL.md
└── workspace-agents-management/
    └── SKILL.md

These files are the source of truth.

Provisioning systems may copy them into:

~/.hermes/skills/

Do not edit installed skills directly when a source-controlled version exists.

Prefer updating the source-controlled version.

### workflows

Contains repeatable procedures.

Examples:

workflows/
├── create-pr.md
├── provision-server.md
├── review-agent-changes.md
└── deploy-pictubook.md

Use workflows when a task has multiple repeatable steps.

### templates

Contains reusable file templates.

Examples:

templates/
├── AGENTS.md
├── DECISIONS.md
├── RUNBOOK.md
├── TASKS.md
└── README.md

Templates should be generic and reusable.

## When To Use Each Area

If a reusable behavior is discovered:
→ Create or update a skill.

If a repeatable procedure is discovered:
→ Create or update a workflow.

If a reusable file structure or document format is discovered:
→ Create or update a template.

## Relationship To Repositories

Project-specific instructions belong inside the project repository.

Examples:

repo/
├── README.md
├── AGENTS.md
├── TASKS.md
├── DECISIONS.md
└── RUNBOOK.md

Only reusable cross-project knowledge belongs in workspace/agents.

## Relationship To Hermes Runtime

The following are runtime artifacts and do not belong in workspace/agents:

~/.hermes/
├── cache/
├── logs/
├── state.db
├── auth.json
├── provider_models_cache.json
└── other runtime files

Runtime files are not source-controlled.

Only source-controlled skills belong in workspace/agents/skills-source.

## Maintenance Rules

Keep files concise.

Avoid duplicate knowledge.

Prefer updating an existing file over creating a near-duplicate.

Delete obsolete workflows and templates.

Do not store secrets.

Never store:

- passwords
- API keys
- tokens
- private keys
- recovery codes
- full .env contents

If a secret is relevant, document only where it is stored.

## README.md Expectations

agents/README.md should describe:

- purpose of the agents directory
- available skills
- available workflows
- available templates
- conventions for adding new resources

When adding a significant reusable asset, update agents/README.md accordingly.
