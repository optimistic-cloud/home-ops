#!/usr/bin/env bash
set -eoux pipefail

set -a; source .env; set +a

docker_container_name="${DOCKER_CONTAINER_NAME:?DOCKER_CONTAINER_NAME is required}"
docker_volume_name="${DOCKER_VOLUME_NAME:?DOCKER_VOLUME_NAME is required}"

backup_export_data_dir="${BACKUP_EXPORT_DATA_DIR:?BACKUP_EXPORT_DATA_DIR is required}"

# export container.env 
export_container_env() {
  docker container inspect "$docker_container_name" | jq -r '.[0].Config.Env[]' > "$backup_export_data_dir/$docker_container_name.env"
}

# export sqlite database
export_sqlite_db() {
  local db_name="${DATABASE_NAME:?DATABASE_NAME is required}"

  docker run --rm -v "$docker_volume_name":/data -v "$backup_export_data_dir":/export alpine/sqlite "/data/$db_name" ".backup '/export/$db_name'"

  result=$(docker run --rm -v "$backup_export_data_dir":/export alpine/sqlite /export/$db_name 'PRAGMA integrity_check;')
  if [ "$result" = "ok" ]; then
    echo "Database is valid"
  else
    echo "Database is NOT valid"
    exit 1
  fi

  docker run --rm -v "$backup_export_data_dir":/export alpine/sqlite /export/$db_name ".tables"
}

mkdir -p "$backup_export_data_dir"
export_container_env

docker container stop "$docker_container_name"
export_sqlite_db