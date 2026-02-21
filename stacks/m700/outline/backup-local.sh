#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backup}"
RESTIC_ENV_FILE="${RESTIC_ENV_FILE:-backup.env}"
RESTIC_IMAGE="${RESTIC_IMAGE:-restic/restic:0.18.1}"
OUTLINE_CONTAINER="${OUTLINE_CONTAINER:-outline}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-outline-postgres}"
OUTLINE_VOLUME="${OUTLINE_VOLUME:-outline_storage-data}"
RESTIC_HOST_TAG="${RESTIC_HOST_TAG:-test-backup}"
LOCAL_REPO_PATH="${LOCAL_REPO_PATH:-/mnt/data/m700/outline}"

cleanup() {
  rm -rf "$BACKUP_DIR"
  docker start "$OUTLINE_CONTAINER"
}

mkdir -p "$BACKUP_DIR"
trap cleanup EXIT

docker exec "$OUTLINE_CONTAINER" printenv > "$BACKUP_DIR/outline.env"
docker stop "$OUTLINE_CONTAINER"
docker exec "$POSTGRES_CONTAINER" printenv > "$BACKUP_DIR/outline-postgres.env"
docker exec "$POSTGRES_CONTAINER" pg_dumpall -U user | gzip > "$BACKUP_DIR/pg_dump.sql.gz"

docker run --rm -i --name outline-restic-backup \
  --env-file "$RESTIC_ENV_FILE" \
  -v "$BACKUP_DIR:/backup" \
  -v "$OUTLINE_VOLUME:/data:ro" \
  -v "$LOCAL_REPO_PATH:$LOCAL_REPO_PATH" \
  -v "$HOME/.cache/restic:/root/.cache/restic" \
  "$RESTIC_IMAGE" backup /data /backup --host "$RESTIC_HOST_TAG"
