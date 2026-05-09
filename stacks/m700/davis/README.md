# Davis

## Init

```bash
just up
just migrate
```

## Backup

Run the full workflow for all repositories:

```bash
just backup
```

Run the workflow for one repository:

```bash
just backup local
```

Run individual steps when you want to inspect or retry a single phase:

```bash
just backup-step prepare
just backup-step backup local
just backup-step check local
just backup-step forget local
just backup-step prune local
just backup-step cleanup
```

Send Healthchecks pings only when you explicitly want them:

```bash
just backup-notify all
just backup-notify local
```

## TODO
- Visit https://dav.optimistic.cloud/dav/ 
- Authenticat with ldap creds
- Browse dav objects