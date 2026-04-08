#!/usr/bin/env bash
set -eoux pipefail

name="outline"
export_path="${EXPORT_DATA:?EXPORT_DATA is required}"

on_exit() {
  docker container start "$name"
}
trap on_exit EXIT

on_error() {
  rm -rf "$export_path"
}
trap on_error ERR

# export container.env 
export_container_env() {
  docker container inspect "$name" | jq -r '.[0].Config.Env[]' > "$export_path/$name.env"
}

# Export Postgres database using docker run
export_postgres_db() {
  docker run --rm \
    -e PGPASSWORD="$POSTGRES_PASSWORD" \
    --network container:outline-postgres \
    postgres:18@sha256:a9abf4275f9e99bff8e6aed712b3b7dfec9cac1341bba01c1ffdfce9ff9fc34a \
    pg_dumpall -h localhost -U "$POSTGRES_USER" | gzip > "$EXPORT_DATA/postgres.sql.gz"
}

mkdir -p "$export_path"
export_container_env

docker container stop "$name"
export_postgres_db