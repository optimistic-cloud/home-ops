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
