set working-directory := 'conf.d/backup/scripts'

help:
    just --list

[group('restic')]
[doc('Backup application')]
backup app provider:
    {{app}}.nu --provider {{provider}}

[group('restic')]
[doc('Backup application with debug logs')]
backup-with-debug app provider $NU_LOG_LEVEL="debug":
    {{app}}.nu --provider {{provider}}

# Restore latest restic snapshot
restore app provider:
    {{app}}.nu restore --provider {{provider}}

# Restore latest restic snapshot with debug logs
restore-with-debug app provider $NU_LOG_LEVEL="debug":
    {{app}}.nu restore --provider {{provider}}
