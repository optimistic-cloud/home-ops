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
    docker exec -it backup-toolkit sh -c "sh -euxo pipefail backup.sh {{app}}"
    #docker exec -it backup-toolkit sh -c "sh -euxo pipefail backup.sh {{app}} > /tmp/backup.log 2>&1"
    #docker exec -it backup-toolkit cat /tmp/backup.log
    # TODO: bind /opt/conf.d/backup/scripts/backup.sh in PATH
