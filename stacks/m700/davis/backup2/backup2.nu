use std/log

const docker_container_name = "davis"
const docker_volume_name = "davis-data"
const database_name = "davis-database.db"

def main [--target: string] {
  if not ( $"compose.($target).yaml" | path exists ) { error make {msg: $"Compose file $"compose.($target).yaml" is not found" } }
  if not ( $"($target).restic.env" | path exists ) { error make {msg: $"Restic environment file $"($target).restic.env" is not found" } }

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
    docker compose -f compose.{{target}}.yaml --env-file {{target}}.restic.env
      run --rm --quiet
      --volume "davis-data:/data/davis-data:ro"
      --volume $"($export_dir):/data/export"
      restic backup /data --exclude-caches --skip-if-unchanged
  )

  rm -rf $export_dir
}
