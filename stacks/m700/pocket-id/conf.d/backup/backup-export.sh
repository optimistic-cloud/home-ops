export_data() {
  # 1 param: source directory
  # 2 param: export directory
  # 3 param: app name
  
  source /opt/conf.d/backup/scripts/export-sqlite.sh

  export_sqlite "$1/data/${3}.db" "$2/${3}.db"
}