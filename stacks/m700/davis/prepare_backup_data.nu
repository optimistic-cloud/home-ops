use std/log

def export-container-envs [docker_container_name: string, backup_export_data_dir: path] {
  let env_file = $"($backup_export_data_dir)/($docker_container_name).env"

  docker container inspect $docker_container_name
  | from json
  | get 0.Config.Env
  | str join "\n"
  | save --force $env_file

  if not ($env_file | path exists) {
    error make { msg: $"File ($env_file) does not exist" }
  }
}

def export-sqlite-database [docker_container_name: string, docker_volume_name: string, database_name: string, backup_export_data_dir: path] {
  docker container stop $docker_container_name
  (
    docker run --rm
      -v $"($docker_volume_name):/data"
      -v $"($backup_export_data_dir):/export"
      alpine/sqlite $"/data/($database_name)" $".backup '/export/($database_name)'"
  )
  docker container start $docker_container_name
}

def main [
  --docker-container-name: string,
  --docker-volume-name: string,
  --database-name: string,
  --backup-export-data-dir: path
] {
  if not ($backup_export_data_dir | path exists) {
    mkdir $backup_export_data_dir
  }

  export-container-envs $docker_container_name $backup_export_data_dir
  export-sqlite-database $docker_container_name $docker_volume_name $database_name $backup_export_data_dir
}