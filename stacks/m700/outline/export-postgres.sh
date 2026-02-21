#!/usr/bin/env bash
set -euo pipefail

DOCKER_CONTAINER="${DOCKER_CONTAINER:-outline-postgres}"
BACKUP_DIR="${BACKUP_DIR:-./backup}"

dump_file="$BACKUP_DIR/${DOCKER_CONTAINER}_pg_dump.sql.gz"

docker exec "$DOCKER_CONTAINER" pg_dumpall -U "$POSTGRES_USER" | gzip > "$dump_file"

if [[ ! -e "$dump_file" ]]; then
  echo "Backup file does not exist: $dump_file" >&2
  exit 1
fi

if [[ ! -s "$dump_file" ]]; then
  echo "Backup file exists but has zero size: $dump_file" >&2
  exit 1
fi

use std/log

def main [container: string, output_dir: path] {

  if not ("POSTGRES_USER" in $env) {
    error make { msg: "POSTGRES_USER is required" }
  }
  let postgres_user = $env.POSTGRES_USER

  if not ($backup_dir | path exists) {
    mkdir $backup_dir
  }

  let dump_file = $"($backup_dir)/($docker_container)_pg_dump.sql.gz"

  ^docker exec $docker_container pg_dumpall -U $postgres_user | ^gzip | save --raw --force $dump_file

  if not ($dump_file | path exists) {
    error make { msg: $"Backup file does not exist: ($dump_file)" }
  }

  let file_size = (ls -D $dump_file | get 0.size | into int)
  if $file_size == 0 {
    error make { msg: $"Backup file exists but has zero size: ($dump_file)" }
  }
}
