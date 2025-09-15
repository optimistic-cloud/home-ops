set dotenv-load

help:
    just --list

[group('restic')]
[doc('Backup application')]
backup app provider:
    nu {{app}}.nu --provider {{provider}}

[group('restic')]
[doc('Backup application with debug logs')]
backup-with-debug app provider $NU_LOG_LEVEL="debug":
    nu {{app}}.nu --provider {{provider}}

# Restore latest restic snapshot
restore app provider:
    env $(cat {{app}}.{{provider}}.env | xargs) nu {{app}}.nu restore

# Restore latest restic snapshot with debug logs
restore-with-debug app provider $NU_LOG_LEVEL="debug":
    env $(cat {{app}}.{{provider}}.env | xargs) nu {{app}}.nu restore
