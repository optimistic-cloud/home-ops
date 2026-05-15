use std/log

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

def restore-from-target [target: string, snapshot_id: string] {
  let compose_file = $"compose.($target).yaml"
  let restic_env_file = $"($target).restic.env"

  if not ( $compose_file | path exists ) { error make {msg: $"Compose file ($compose_file) is not found" } }
  if not ( $restic_env_file | path exists ) { error make {msg: $"Restic environment file ($restic_env_file) is not found" } }

  with-tmp-dir $name {|restore_dir|
    (
      docker compose -f $compose_file --env-file $restic_env_file
        run --rm --quiet
        --volume $"($restore_dir):/data"
        restic restore $snapshot_id --target /data
    )
  }
}

def main [target: string, snapshot_id: string] {
  restore-from-target $target $snapshot_id
}
