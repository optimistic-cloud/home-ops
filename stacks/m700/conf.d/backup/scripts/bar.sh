#!/usr/bin/just --justfile

help:
    just --list

# Run restic backup
#backup app:
#    nu {{app}}.nu

[group('restic')]
[doc('Backup application')]
backup app provider:
    #!/usr/bin/env sh
    set -euox pipefail
    env $(cat .env.{{app}}.{{provider}} | xargs) nu {{app}}.nu

# Run restic backup with debug logs
backup-with-debug app $NU_LOG_LEVEL="debug":
    nu {{app}}.nu

# Restore latest restic snapshot
restore app:
    nu {{app}}.nu restore

# Restore latest restic snapshot with debug logs
restore-with-debug app $NU_LOG_LEVEL="debug":
    nu {{app}}.nu restore
