export_data() {
  local backup_dir=$1
  local export_dir=$2
  local app=$3
  sqlite3 "$backup_dir/data/${app}.db" ".backup '$export_dir/${app}.db'"
}
