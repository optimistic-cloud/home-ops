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
