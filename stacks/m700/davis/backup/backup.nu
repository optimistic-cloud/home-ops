use std/log

const docker_container_name = "davis"
const docker_volume_name = "davis-data" 

def run-in-docker [...args: string] {
  (
    ^docker compose -f docker-compose.backup.yaml run --rm --quiet
      --name "davis-backup-restic"
      --volume /mnt/data/m700/davis:/repo
      --volume davis-data:/data/davis-data:ro
      --volume $"($env.BACKUP_EXPORT_DATA_DIR):/data/export"
      ...$args
  )
}

def main [--restic-env-file: path, --restic-password-file: path] {
  if not ($restic_env_file | path exists ) { error make {msg: $"Restic environment file ($restic_env_file) is not found" } }
  if not ($restic_password_file | path exists ) { error make {msg: $"Restic password file ($restic_password_file) is not found" } }

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
      --database-name "davis-database.db" 
      --target-dir $export_dir
  )

  with-env {
    RESTIC_ENV_FILE: ($restic_env_file | path expand)
    RESTIC_PASSWORD_FILE: ($restic_password_file | path expand)
    BACKUP_EXPORT_DATA_DIR: $export_dir
  } {
    run-in-docker backup
    run-in-docker forget
    run-in-docker check
    run-in-docker restic stats
  }
}