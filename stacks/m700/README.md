# m700 stack

## Applications

### Pocket ID

- https://id.optimistic.cloud/setup

### Gitea

Add oidc from cli

Gitea: docker exec -it gitea /bin/bash
Gitea: gitea admin auth add-oauth \
        --name "Optimistic Cloud" \
        --provider openidConnect \
        --key   "<key>" \
        --secret "<secret>" \
        --auto-discover-url "https://id.optimistic.cloud/.well-known/openid-configuration" \
        --scopes "openid,email,profile"

## Backups

### Backup types
- Backups are keyed by `backup_type`: `local`, `onsite`, `offsite`.
- Discover available types for an app: `just backup-types <app>`

### Initialize a repository
- Create `<app>.<backup_type>.restic.env`
- Per app/type: `just init <app> <backup_type>`

### Run a backup
- Single type: `just backup <app> <backup_type>`
- All types: `just backup-all <app>`

### Prune old snapshots
- Per app/type: `just prune <app> <backup_type>`
- All types: `just prune-all <app>`