if [ -f "source /opt/conf.d/backup/scripts/container.sh" ]; then
  source source /opt/conf.d/backup/scripts/container.sh
fi

pre_backup() {
  # 1 param: source directory
  local source_dir=$1
  # 2 param: export directory
  local export_dir=$2
  # 3 param: app name
  local app=$3

  # Stop container
  if declare -F stop_container >/dev/null; then
      stop_container "${app}"
  else
    exit 3
  fi

  # export sqlite database
  source /opt/conf.d/backup/scripts/export-sqlite.sh
  export_sqlite "${source_dir}/appdata/db.sqlite3" "${export_dir}/db.sqlite3"
}

post_backup() {
  # 1 param: source directory
  local source_dir=$1
  # 2 param: export directory
  local export_dir=$2
  # 3 param: app name
  local app=$3

  if declare -F stop_container >/dev/null; then
      start_container "${app}"
  else
    exit 3
  fi
}
