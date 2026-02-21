#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/backup.offsite.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing environment file: $ENV_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backup}"
DOCKER_CONTAINER="${DOCKER_CONTAINER:-outline-postgres}"
POSTGRES_USER="${POSTGRES_USER:-user}"
RESTIC_IMAGE="${RESTIC_IMAGE:-restic/restic:0.18.1}"
HC_URL="${HC_HOST:+https://${HC_HOST}/ping/${HC_PING_KEY}/outline-offsite?create=1}"

rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

ping_status() {
  local status="$1"

  if [[ -z "$HC_URL" ]]; then
    return 0
  fi

  curl --fail --silent --show-error "$HC_URL&status=$status" >/dev/null || true
}

cleanup() {
  docker start outline >/dev/null 2>&1 || true
  rm -rf "$BACKUP_DIR"
}

on_error() {
  ping_status error
}

create_postgres_dump() {
  local dump_file="$BACKUP_DIR/${DOCKER_CONTAINER}_pg_dump.sql.gz"

  docker exec "$DOCKER_CONTAINER" pg_dumpall -U "$POSTGRES_USER" | gzip > "$dump_file"

  if [[ ! -e "$dump_file" ]]; then
    echo "Backup file does not exist: $dump_file" >&2
    exit 1
  fi

  if [[ ! -s "$dump_file" ]]; then
    echo "Backup file exists but has zero size: $dump_file" >&2
    exit 1
  fi
}

trap cleanup EXIT
trap on_error ERR

docker exec outline printenv > "$BACKUP_DIR/outline.env"
docker stop outline
docker exec "$DOCKER_CONTAINER" printenv > "$BACKUP_DIR/${DOCKER_CONTAINER}.env"
create_postgres_dump

docker run --rm --name \
  outline-restic-backup \
  --env-file "$ENV_FILE" \
  -v "$BACKUP_DIR:/backup" \
  -v outline_storage-data:/data:ro \
  -v "$HOME/.cache/restic:/root/.cache/restic" \
  "$RESTIC_IMAGE" backup /data /backup --host "{{HOSTNAME}"

ping_status success