use std/log

use with-lockfile.nu *
use with-healthcheck.nu *
use with-docker.nu *
use utils.nu *

const app = "vaultwarden"
const hc_slug = "vaultwarden-backup"
const container_name = "vaultwarden"
const data_docker_volume = "vaultwarden-data"

def main [--provider: string] {
    open env.toml | load-env
    
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

                let env_file = $"($app).($provider).restic.env"

                # Run backup with ping
                with-ping {
                    {
                        data: $data_docker_volume
                        config: $backup_docker_volume
                    } | restic-backup --env-file $env_file
                }
                
                # Run check with ping
                with-ping {
                    restic-check --env-file $env_file
                }
            }
        }
    }
}

def "main init" [--provider: string] { 
    $"($app).($provider).restic.env" | with-restic init 
}

def "main stats" [--provider: string] { 
    $"($app).($provider).restic.env" | with-restic stats 
}

def "main ls" [--provider: string] { 
    $"($app).($provider).restic.env" | with-restic "ls latest" 
}

def "main snapshots" [--provider: string] { 
    $"($app).($provider).restic.env" | with-restic "snapshots --latest 5" 
}