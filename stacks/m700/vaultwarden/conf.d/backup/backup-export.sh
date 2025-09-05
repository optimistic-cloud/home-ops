export_data() {
  # 1 param: source directory
  local source_dir=$1
  # 2 param: export directory
  local export_dir=$2
  # 3 param: app name
  local app=$3

  # Stop container
  source /opt/conf.d/backup/scripts/container.sh
  stop_container "${app}"

  # export sqlite database
  source /opt/conf.d/backup/scripts/export-sqlite.sh
  export_sqlite "${source_dir}/appdata/db.sqlite3" "${export_dir}/db.sqlite3"
}

pre_backup() {
  # 1 param: source directory
  local source_dir=$1
  # 2 param: export directory
  local export_dir=$2
  # 3 param: app name
  local app=$3

  # Stop container
  source /opt/conf.d/backup/scripts/container.sh
  stop_container "${app}"

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

  source /opt/conf.d/backup/scripts/container.sh
  stop_container "${app}"
}
