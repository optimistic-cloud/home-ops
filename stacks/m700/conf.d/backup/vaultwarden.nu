use std/log

use ./lib/with-lockfile.nu *
use ./lib/with-healthcheck.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

const app = "vaultwarden"
const hc_slug = "vaultwarden-backup"
const container_name = "vaultwarden"
const data_docker_volume = "vaultwarden-data"

def main [--env-file: path, --provider-env-file: path] {
    env_file | require
    provider-env-file | require

    open $env_file | load-env
    
    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-lockfile $app {
        with-healthcheck {
            with-backup-docker-volume {
                let backup_docker_volume = $in

                # Stops the container if it is running, and starts it again afterwards
                with-stopped-docker-container --name $app {
                    # Export sqlite database
                    {
                        src_volume: $data_docker_volume
                        src_path: "/data/db.sqlite3"
                    } | export-sqlite-database-in-volume --volume $backup_docker_volume
                }

                # Export env from container
                $container_name | export-env-from-container --volume $backup_docker_volume

                # Run backup with ping
                with-ping {
                    {
                        data: $data_docker_volume
                        config: $backup_docker_volume
                    } | restic-backup --env-file $provider_env_file
                }
                
                # Run check with ping
                with-ping {
                    restic-check --env-file $provider_env_file
                }
            }
        }
    }
}

def "main init" [--provider-env-file: path] { 
    $provider_env_file | with-restic ["init"]
}

def "main stats" [--provider-env-file: path] { 
    $provider_env_file | with-restic ["stats"] 
}

def "main ls" [--provider-env-file: path] { 
    $provider_env_file | with-restic ["ls", "latest"] 
}

def "main snapshots" [--provider-env-file: path] { 
    $provider_env_file | with-restic ["snapshots", "--latest", "5"] 
}

def "main restore" [--provider-env-file: path, --restore-path: path] {
    if ($restore_path | path exists) {
        error make {msg: "Restore path already exists" }
    }

    restic-restore --env-file $provider_env_file --target $restore_path
}
