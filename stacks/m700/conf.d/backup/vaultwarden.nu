use std/log

use ./lib/with-backup-template.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

const app = "vaultwarden"
const hc_slug = "vaultwarden-backup"
const container_name = "vaultwarden"
const data_docker_volume = "vaultwarden-data"

def main [--provider-env-file: path] {
    with-backup-template $app {
        let backup_docker_volume = $in

        # Stops the container if it is running, and starts it again afterwards
        with-stopped-docker-container --name $app {
            # Export sqlite database
            {
                src_volume: $data_docker_volume
                src_path: "/data/db.sqlite3"
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
