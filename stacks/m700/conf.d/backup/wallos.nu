use std/log

use ./lib/with-backup-template.nu *
use ./lib/with-docker.nu *
use ./lib/lib.nu *

const app = "wallos"
const container_name = "wallos"
const data_docker_volume = "wallos-data"

def main [...provider_env_files: path] {
    $app | with-backup-template --provider-env-files $provider_env_files {
        let backup_docker_volume = $in

        # Stops the container if it is running, and starts it again afterwards
        with-stopped-docker-container --name $app {
            # Export sqlite database
            {
                src_volume: $data_docker_volume
                src_path: "/data/db/wallos.db"
            } | export-sqlite-database-in-volume --volume $backup_docker_volume
        }

        {
            container_name: $container_name
            volumes: {
                config: $backup_docker_volume
            }
        }
    }
}
