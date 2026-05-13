use std/log
use ../../conf.d/backup/lib/restic-compose.nu *

const name = "vaultwarden"
const docker_container_name = $name
const docker_volume_name = $"($name)-data"
const database_name = "db.sqlite3"

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

def with-tmp-dir [name: string, operation: closure] {
  let export_dir = (^mktemp -d $"/tmp/($name)-backup-XXXXXX" | str trim)

  try {
    do $operation $export_dir
    rm -rf $export_dir
  } catch {|err|
    # TODO: https://github.com/nushell/nushell/issues/15279
    rm -rf $export_dir
    error make $err
  }
}

def main [--target: string] {

  with-tmp-dir $name {|export_dir|
    (
      nu export_container_envs.nu
        --docker-container-name $docker_container_name
        --target-dir $export_dir
    )
    (
      nu export_sqlite.nu
        --docker-container-name $docker_container_name
        --docker-volume-name $docker_volume_name
        --database-name $database_name
        --target-dir $export_dir
    )

    with-stopped-docker-container $docker_container_name {
      (
        docker compose ...(get-restic-compose-args $target)
          run --rm --quiet
          --volume $"($docker_volume_name):/data/($docker_volume_name):ro"
          --volume $"($export_dir):/data/export"
          restic backup /data --exclude-caches --skip-if-unchanged
      )
    }
  }
}
