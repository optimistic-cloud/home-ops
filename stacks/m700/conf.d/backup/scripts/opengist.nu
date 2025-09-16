use std/log

use with-lockfile.nu *
use with-healthcheck.nu *
use with-docker.nu *
use utils.nu *

const app = "opengist"
const hc_slug = "opengist-backup"
const container_name = "opengist"
const data_docker_volume = "opengist-data"

def main [--provider: string] {
    open env.toml | load-env

    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-lockfile $app {
        with-healthcheck {
            with-backup-docker-volume {
                let backup_docker_volume = $in

                with-stopped-docker-container --name $app {
                    # Export sqlite database
                    {
                        src_volume: $data_docker_volume
                        src_path: "/data/opengist.db"
                    } | export-sqlite-database-in-volume --volume $backup_docker_volume
                }

                # Export env from container
                $container_name | export-env-from-container-to-volume --volume $backup_docker_volume


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
