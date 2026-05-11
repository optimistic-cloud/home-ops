use std/log

def run-in-docker [...args: string] {
  ^docker compose -f docker-compose.backup.yaml run --rm --quiet ...$args
}

def main [--restic-env-file: path, --restic-password-file: path, --working-dir: path] {
  if not ($working_dir | path exists) { error make { msg: $"Directory ($working_dir) is not found" } }
  if not ($restic_env_file | path exists ) { error make {msg: $"Restic environment file ($restic_env_file) is not found" } }

  let export_data_dir = $working_dir | path join "export-data" | path expand
  mkdir $export_data_dir

  (
    nu export_container_envs.nu
      --docker-container-name "davis" 
      --target-dir $export_data_dir
  )
  (
    nu export_sqlite.nu 
      --docker-container-name "davis" 
      --docker-volume-name "davis-data" 
      --database-name "davis-database.db" 
      --target-dir $export_data_dir
  )

  with-env {
    RESTIC_ENV_FILE: ($restic_env_file | path expand)
    RESTIC_PASSWORD_FILE: ($restic_password_file | path expand)
    BACKUP_EXPORT_DATA_DIR: $export_data_dir
  } {

    run-in-docker backup
    run-in-docker forget
    run-in-docker check
    un-in-docker restic stats
  }
}