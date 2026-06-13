# Migration Plan

## Current Evolution

```text
Windows Host
  -> Hyper-V Ubuntu VM
  -> Dedicated Ubuntu Server
```

## Migration Goals

- Preserve service continuity while moving to dedicated hardware
- Move infrastructure definition into Git
- Reduce dependence on one-off manual configuration
- Separate reproducible server setup from persistent service data

## Recommended Migration Sequence

1. Build this repository structure and keep it as the source of truth.
2. Recreate the target server baseline on the new Ubuntu host.
3. Validate SSH, package installation, Docker, and directory layout.
4. Export or archive current Forgejo data from the VM.
5. Recreate the Forgejo service on the dedicated server.
6. Restore Forgejo data and verify repositories and access.
7. Migrate Hermes and other lower-risk services.
8. Migrate n8n once persistence requirements are fully understood.
9. Retire the Hyper-V VM after validation and rollback confidence.

## Risks To Manage

- Missing service-specific environment variables
- Ownership or permission mismatches on bind mounts
- Port conflicts on the new host
- Assuming synchronization is equivalent to backup

## Success Criteria

- A fresh Ubuntu server can be provisioned from this repository
- Forgejo data can be restored successfully
- Service layout is documented and understandable
- Recovery steps are clear enough to repeat under pressure
