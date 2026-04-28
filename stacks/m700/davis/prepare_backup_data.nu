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

def with-stopped-docker-container [--name: string, operation: closure] {
  docker container stop $name
  try {
      do $operation
       docker container start $name
  } catch {|err|
      # https://github.com/nushell/nushell/issues/15279
      docker container start $name
      error make $err
  }
}

def export-sqlite-database [docker_container_name: string, docker_volume_name: string, database_name: string, backup_export_data_dir: path] {
  with-stopped-docker-container --name $docker_container_name { 
    (
      docker run --rm
        -v $"($docker_volume_name):/data"
        -v $"($backup_export_data_dir):/export"
        alpine/sqlite $"/data/($database_name)" $".backup '/export/($database_name)'"
    )
  }

  docker run --rm -v $"($backup_export_data_dir):/data" alpine:3.23.4 chown -R 1000:1000 /data
}

def main [
  --docker-container-name: string,
  --docker-volume-name: string,
  --database-name: string,
  --backup-export-data-dir: path
] {
  if not ($backup_export_data_dir | path exists) {
    error make { msg: "Export dir does not exist" }
  }

  export-container-envs $docker_container_name $backup_export_data_dir
  export-sqlite-database $docker_container_name $docker_volume_name $database_name $backup_export_data_dir
}