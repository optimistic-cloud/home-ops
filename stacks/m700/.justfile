help:
    just --list --list-submodules

[group('commands')]
[doc('Start the stack')]
up:
    docker compose up -d

[group('commands')]
[doc('Stop the stack')]
down:
    docker compose down

[group('commands')]
[doc('Get logs for a service')]
logs service:
    docker compose logs -f {{service}}

[group('restic')]
[doc('Init restic repository')]
backup app:
    docker exec -it backup-toolkit bash -exuo pipefail init.sh {{app}}

[group('restic')]
[doc('Backup application with restic')]
backup app:
    docker exec -it backup-toolkit bash -exuo pipefail backup.sh {{app}}
