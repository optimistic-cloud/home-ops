use std/log

use ./lib/with-lockfile.nu *
use ./lib/with-healthcheck.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

const app = "opengist"
const hc_slug = "opengist-backup"
const container_name = "opengist"
const data_docker_volume = "m700_opengist-data"

def main [--env-file: path, --provider-env-file: path] {
    $env_file | require | open | load-env

    $hc_slug | configure-hc-api

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

                {
                    container_name: $container_name
                    volumes: {
                        data: $data_docker_volume
                        config: $backup_docker_volume
                    }
                } | backup --provider-env-file $provider_env_file
            }
        }
    }
}
