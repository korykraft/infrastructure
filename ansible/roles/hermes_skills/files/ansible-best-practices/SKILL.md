---

name: ansible-best-practices

description: Use when editing Ansible roles, inventories, variables, handlers, and playbooks.

---

# Ansible Best Practices

Prefer idempotent tasks.

Use variables instead of hardcoded usernames or paths.

Use handlers for service restarts.

Avoid one-off shell commands when a native Ansible module exists.

Never store secrets in repo files.
