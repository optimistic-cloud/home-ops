#!/usr/bin/env bash
set -eoux pipefail

name="wallos"
export_path="${EXPORT_DATA:?EXPORT_DATA is required}"

# export container.env 
export_container_env() {
  docker container inspect "$name" | jq -r '.[0].Config.Env[]' > "$export_path/$name.env"
}

# export sqlite database
export_sqlite_db() {
  local volume_name="$name-data"
  local db_name="wallos.db"

  docker run --rm -v "$volume_name":/data -v "$export_path":/export alpine/sqlite "/data/$db_name" ".backup '/export/$db_name'"

  result=$(docker run --rm -v "$export_path":/export alpine/sqlite /export/$db_name 'PRAGMA integrity_check;')
  if [ "$result" = "ok" ]; then
    echo "Database is valid"
  else
    echo "Database is NOT valid"
    exit 1
  fi

  docker run --rm -v "$export_path":/export alpine/sqlite /export/$db_name ".tables"
}

mkdir -p "$export_path"
export_container_env

docker container stop "$name"
export_sqlite_db