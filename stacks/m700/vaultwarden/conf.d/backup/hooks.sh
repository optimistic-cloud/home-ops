container_sh="/opt/conf.d/backup/scripts/container.sh"
if [ -f "${container_sh}" ]; then
  source "${container_sh}"
fi

export-sqlite_sh="/opt/conf.d/backup/scripts/export-sqlite.sh"
if [ -f "${export-sqlite_sh}" ]; then
  source "${export-sqlite_sh}"
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
  if declare -F stop_container >/dev/null; then
      export_sqlite "${source_dir}/appdata/db.sqlite3" "${export_dir}/db.sqlite3"
  else
    exit 3
  fi
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
