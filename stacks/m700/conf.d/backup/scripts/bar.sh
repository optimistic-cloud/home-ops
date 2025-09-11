#!/usr/bin/just --justfile

help:
    just --list

[group('restic')]
[doc('Backup application')]
backup app provider:
    env $(cat .env.{{app}}.{{provider}} | xargs) nu {{app}}.nu

[group('restic')]
[doc('Backup application with debug logs')]
backup-with-debug app $NU_LOG_LEVEL="debug":
    env $(cat .env.{{app}}.{{provider}} | xargs) nu {{app}}.nu

# Restore latest restic snapshot
restore app:
    env $(cat .env.{{app}}.{{provider}} | xargs) nu {{app}}.nu restore

# Restore latest restic snapshot with debug logs
restore-with-debug app $NU_LOG_LEVEL="debug":
    env $(cat .env.{{app}}.{{provider}} | xargs) nu {{app}}.nu restore
