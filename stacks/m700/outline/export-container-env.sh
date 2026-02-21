#!/usr/bin/env bash
set -euo pipefail

dump_file="$BACKUP_DIR/${DOCKER_CONTAINER}.env"

docker exec "$DOCKER_CONTAINER" printenv > "$dump_file"

if [[ ! -e "$dump_file" ]]; then
  echo "Backup file does not exist: $dump_file" >&2
  exit 1
fi

if [[ ! -s "$dump_file" ]]; then
  echo "Backup file exists but has zero size: $dump_file" >&2
  exit 1
fi
