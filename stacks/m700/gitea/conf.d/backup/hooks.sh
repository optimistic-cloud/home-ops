pre_backup() {
  # 1 param: source directory
  local source_dir=$1
  # 2 param: export directory
  local export_dir=$2
  # 3 param: app name
  local app=$3

  local dump_name=gitea-dump.tar.gz
  local dump_location=/var/lib/gitea

  docker exec -u git gitea rm -f "${dump_location}/${dump_name}"
  docker exec -u git gitea /usr/local/bin/gitea \
    dump --work-path /tmp \
      --file "${dump_name}" \
      --config /etc/gitea/app.ini \
      --database sqlite3 \
      --type tar.gz
  docker cp gitea:"${dump_location}/${dump_name}" "${export_dir}"
  docker exec -u git gitea rm -f "${dump_location}/${dump_name}"
}

post_backup() {
  # 1 param: source directory
  local source_dir=$1
  # 2 param: export directory
  local export_dir=$2
  # 3 param: app name
  local app=$3

  #docker container start "${app}"
}
