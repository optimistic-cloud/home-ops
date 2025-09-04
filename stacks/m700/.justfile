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

[group('commands')]
[doc('Backup application')]
backup app:
    docker exec -it backup-toolkit sh -c "set -euxo pipefail; sh /opt/conf.d/backup/scripts/backup.sh {{app}}"
    # TODO: bind /opt/conf.d/backup/scripts/backup.sh in PATH
