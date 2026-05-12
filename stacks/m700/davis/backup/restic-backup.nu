use std/log

const docker_container_name = "davis"

def compose-file [target: string]: nothing -> string {
  match $target {
    'local' => "compose.local.yaml",
    'offsite' => "compose.s3.yaml",
    'onsite' => "compose.s3.yaml",
    _ => (error make {msg: $"Unknown target ($target)"})
  }
}
const docker_volume_name = "davis-data"
const database_name = "davis-database.db"

def main [--target: string] {
  let compose_file = compose-file $target
  let restic_env_file = $"($target).restic.env"

  if not ( $compose_file | path exists ) { error make {msg: $"Compose file ($compose_file) is not found" } }
  if not ( $restic_env_file | path exists ) { error make {msg: $"Restic environment file ($restic_env_file) is not found" } }

  let export_dir = (^mktemp -d /tmp/davis-backup-XXXXXX | str trim)

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
  (
    docker compose -f $compose_file --env-file $restic_env_file
      run --rm --quiet
      --volume "davis-data:/data/davis-data:ro"
      --volume $"($export_dir):/data/export"
      restic backup /data --exclude-caches --skip-if-unchanged
  )

  rm -rf $export_dir
}
