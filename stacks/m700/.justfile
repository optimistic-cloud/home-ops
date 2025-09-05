help:
    just --list --list-submodules

[group('docker')]
[doc('Start the stack')]
up:
    docker compose up -d

[group('docker')]
[doc('Stop the stack')]
down:
    docker compose down

[group('docker')]
[doc('Get logs for a service')]
logs service:
    docker compose logs -f {{service}}

[group('restic')]
[doc('Init repository')]
init app:
    docker exec -it backup-toolkit bash -exuo pipefail init.sh {{app}}

[group('restic')]
[doc('Backup application')]
backup app:
    docker exec -it backup-toolkit bash -exuo pipefail backup.sh {{app}}

[group('restic')]
[doc('Restore backup for an application')]
restore app provider:
    docker exec -it backup-toolkit bash -exuo pipefail restore.sh {{app}} {{provider}} 
    docker compose -f {{app}}/conf.d/restore/docker-compose.yml up -d