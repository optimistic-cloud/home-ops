use std/log

def append-to-file [filename: path] {
  $"($in)(char eol)" | save --append $filename
}

def run-in-docker [command: string] {
  ^docker compose -f docker-compose.backup.yaml run --rm --quiet $command out+err> $logfile
}

def main [--restic-env-file: path, --working-dir: path, --logfile: path] {
  if not ($working_dir | path exists) { error make { msg: $"Directory ($working_dir) is not found" } }
  if (ls -a $working_dir | is-not-empty) { error make { msg: $"Directory ($working_dir) is not empty" } }
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
    BACKUP_EXPORT_DATA_DIR: $export_data_dir
    HOSTNAME: "m700"
  } {
    let logfile = $working_dir 
      | path join $logfile 
      | path expand
    
    run-in-docker backup
    '---' | append-to-file $logfile
    run-in-docker forget
    '---' | append-to-file $logfile
    run-in-docker check
    '---' | append-to-file $logfile
    run-in-docker restic stats
  }
}