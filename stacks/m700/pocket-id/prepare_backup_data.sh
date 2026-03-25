#!/usr/bin/env bash
set -eoux pipefail

name="pocket-id"
export_path="${EXPORT_DATA:?EXPORT_DATA is required}"

# export container.env 
export_container_env() {
  docker container inspect "$name" | jq -r '.[0].Config.Env[]' > "$export_path/$name.env"
}

# export sqlite database
export_sqlite_db() {
  local volume_name="$name-data"
  local db_name="pocket-id.db"

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

export_encfile() {
  local volume_name="$name-data"
  local tmp_dir=$(mktemp -d)

  docker cp "$name":/app/secrets/pocket-id.encfile "$tmp_dir"
  docker run -u 1000:1000 --rm -v "$tmp_dir":/data -v "$export_path":/export alpine sh -c "cp -r /data/* /export"
}

export_container_env
export_sqlite_db
export_encfile
