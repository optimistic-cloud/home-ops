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
  docker run --rm \
    -e PGPASSWORD="$POSTGRES_PASSWORD" \
    --network container:outline-postgres \
    postgres:18 \
    pg_dumpall -h localhost -U "$POSTGRES_USER" | gzip > "$EXPORT_DATA/backup.sql.gz"
}

mkdir -p "$export_path"
export_container_env

docker container stop "$name"
export_postgres_db