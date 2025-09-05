pre_backup() {
  # 1 param: source directory
  local source_dir=$1
  # 2 param: export directory
  local export_dir=$2
  # 3 param: app name
  local app=$3

  local dump_name=gitea-dump

  docker container stop "${app}"
  docker exec -u git gitea rm -f /tmp/gitea-dump-*
  docker exec -u git gitea /usr/local/bin/gitea \
    dump --work-path /tmp \
      --file "${dump_name}" \
      --config /etc/gitea/app.ini \
      --database sqlite3 \
      --type tar.gz
  docker cp gitea:/tmp/"${dump_name}".tar.gz "${export_dir}"
  docker exec -u git gitea rm -f /tmp/gitea-dump-*
  ls -la "${export_dir}"
}

post_backup() {
  # 1 param: source directory
  local source_dir=$1
  # 2 param: export directory
  local export_dir=$2
  # 3 param: app name
  local app=$3

  docker container start "${app}"
}
