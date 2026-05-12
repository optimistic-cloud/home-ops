use std/log

const ALPINE_SQLITE_IMAGE = "alpine/sqlite"
const ALPINE_IMAGE = "alpine"

def with-stopped-docker-container [name: string, operation: closure] {
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

def export-sqlite-database [
  docker_container_name: string, 
  docker_volume_name: string, 
  database_name: string, 
  target_dir: path
] {
  with-stopped-docker-container $docker_container_name { 
    (
      docker run --rm
        -v $"($docker_volume_name):/data"
        -v $"($target_dir):/export"
        $ALPINE_SQLITE_IMAGE $"/data/($database_name)" $".backup '/export/($database_name)'"
    )
  }

  docker run --rm -v $"($target_dir):/data" $ALPINE_IMAGE chown -R 1000:1000 /data

  # check
  let exported_db_path = $target_dir | path join $database_name
  if not ($exported_db_path | path exists) {
    error make { msg: $"Exported database file ($exported_db_path) does not exist" }
  }
}

def main [
  --docker-container-name: string,
  --docker-volume-name: string,
  --database-name: string,
  --target-dir: path
] {
  let export_dir = $target_dir | path expand
  
  log debug $"Exporting SQLite database for 
    container: ($docker_container_name)
    volume: ($docker_volume_name)
    database: ($database_name) 
    to directory: ($export_dir)"

    (export-sqlite-database 
        $docker_container_name 
        $docker_volume_name 
        $database_name 
        $export_dir
    )

}