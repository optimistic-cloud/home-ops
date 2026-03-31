#!/usr/bin/env bash
set -eoux pipefail

name="outline"
export_path="${EXPORT_DATA:?EXPORT_DATA is required}"

# export container.env 
export_container_env() {
  docker container inspect "$name" | jq -r '.[0].Config.Env[]' > "$export_path/$name.env"
}

# Export Postgres database using docker run
export_postgres_db() {
  local db_container="${1:-${name}-postgres}"
  local db_name="${2:-$name}"
  local db_user="${3:-postgres}"
  local db_password="${4:-$POSTGRES_PASSWORD}"
  local backup_file="${5:-$export_path/${db_name}_pg_backup.sql.gz}"

  if [ -z "$db_password" ]; then
    echo "POSTGRES_PASSWORD is required as argument 4 or env var" >&2
    return 1
  fi

  docker run --rm \
    -e PGPASSWORD="$db_password" \
    --network container:"$db_container" \
    postgres:15-alpine \
    pg_dumpall -U "$POSTGRES_USER" "$db_name" | gzip > "$backup_file"

  if [[ ! -e "$backup_file" ]]; then
    echo "Backup file does not exist: $backup_file" >&2
    return 1
  fi
  if [[ ! -s "$backup_file" ]]; then
    echo "Backup file exists but has zero size: $backup_file" >&2
    return 1
  fi
  echo "Postgres backup complete: $backup_file"
}

mkdir -p "$export_path"
export_container_env

docker container stop "$name"
export_postgres_db outline-postgres