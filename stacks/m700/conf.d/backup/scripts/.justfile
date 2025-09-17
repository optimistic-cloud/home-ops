set working-directory := 'conf.d/backup/scripts'

help:
    just --list

[group('restic')]
[doc('Backup application')]
backup app provider:
    #echo "SHELL=$SHELL"
    which sh || true
    which bash || true
    which nu || true
    ls -l /bin/sh || true
    nu {{app}}.nu --provider {{provider}}

[group('restic')]
[doc('Backup application with debug logs')]
backup-with-debug app provider $NU_LOG_LEVEL="debug":
    nu {{app}}.nu --provider {{provider}}

# Restore latest restic snapshot
restore app provider:
    nu {{app}}.nu restore --provider {{provider}}

# Restore latest restic snapshot with debug logs
restore-with-debug app provider $NU_LOG_LEVEL="debug":
    nu {{app}}.nu restore --provider {{provider}}
