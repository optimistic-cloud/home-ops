export_sqlite_sh="/opt/conf.d/backup/scripts/export-sqlite.sh"
if [ -f "${export_sqlite_sh}" ]; then
  source "${export_sqlite_sh}"
fi

pre_backup() {
  # 1 param: source directory
  local source_dir=$1
  # 2 param: export directory
  local export_dir=$2
  # 3 param: app name
  local app=$3

  # Stop container
  docker container stop "${app}"

  # export sqlite database
  if declare -F export_sqlite >/dev/null; then
      export_sqlite "${source_dir}/appdata/$3.db" "${export_dir}/$3.db"
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

  docker container start "${app}"
}
