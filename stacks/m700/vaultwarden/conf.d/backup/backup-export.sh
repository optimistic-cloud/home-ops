export_data() {
  # 1 param: source directory
  # 2 param: export directory
  # 3 param: app name
  
  source /opt/conf.d/backup/export-sqlite.sh

  export_sqlite "$1/data/db.sqlite3" "$2/db.sqlite3"
}