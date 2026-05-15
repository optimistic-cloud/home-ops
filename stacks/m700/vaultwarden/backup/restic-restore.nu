use std/log

const name = "vaultwarden"
const docker_container_name = $name
const docker_volume_name = $"($name)-data"
const database_name = "db.sqlite3"

def restore-from-target [target: string, snapshot_id: string] {
  let compose_file = $"compose.($target).yaml"
  let restic_env_file = $"($target).restic.env"

  if not ( $compose_file | path exists ) { error make {msg: $"Compose file ($compose_file) is not found" } }
  if not ( $restic_env_file | path exists ) { error make {msg: $"Restic environment file ($restic_env_file) is not found" } }

  (
    docker compose -f $compose_file --env-file $restic_env_file
      run --rm --quiet
      --volume "./restore-data:/data"
      restic restore $snapshot_id --target /data
  )
}

def main [target: string, snapshot_id: string] {
  restore-from-target $target $snapshot_id
}
