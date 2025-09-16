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

                # Run backup with ping
                with-ping {
                    let volumes = {
                        data: $data_docker_volume
                        config: $backup_docker_volume
                    }
                    $"($app).($provider).restic.env" | restic-backup $volumes
                }
                
                # Run check with ping
                with-ping {
                    $"($app).($provider).restic.env" | restic-check
                }
            }
        }
    }
}
