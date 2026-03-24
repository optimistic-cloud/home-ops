#!/usr/bin/env bash
set -eoux pipefail

export_path="${EXPORT_DATA:?EXPORT_DATA is required}"

# export container.env 
docker container inspect gitea | jq -r '.[0].Config.Env[]' > "$export_path/gitea.env"

# create backup archive

dump_location="/var/lib/gitea"
gitea_archive_name="gitea-dump.tar.gz"
tmp_dir=$(mktemp -d)

cleanup() {
  # remove dump from container
  docker exec -u git gitea rm -f "${dump_location}/${gitea_archive_name}"
  # remove dump from export path
  rm -f "${export_path}/${gitea_archive_name}"
  # remove extracted dump from temp path
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

## remove old dump, create new dump
docker exec -u git gitea rm -f "${dump_location}/${gitea_archive_name}"

## create new dump
docker exec -u git gitea /usr/local/bin/gitea \
    dump --work-path /tmp \
    --file "${gitea_archive_name}" \
    --config /etc/gitea/app.ini \
    --database sqlite3 \
    --type tar.gz

docker cp gitea:"${dump_location}/${gitea_archive_name}" "$export_path"
tar -xzf "${export_path}/${gitea_archive_name}" -C "${tmp_dir}"
docker run --rm \
  -v "${export_path}:/data:rw" \
  -v "${tmp_dir}:/import:ro" \
  alpine sh -c "mkdir -p /data/gitea-dump && cp -r /import/* /data/gitea-dump"
