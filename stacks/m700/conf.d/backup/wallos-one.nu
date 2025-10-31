use std/log

use ./lib/with-backup-template-one.nu *
use ./lib/with-docker.nu *
use ./lib/lib.nu *

const app = "wallos"
const container_name = "wallos"
const data_docker_volume = "wallos-data"

def main [provider_name: string, provider_env_file: path] {
    $app | with-backup-template-one $provider_name $provider_env_file {
        let backup_docker_volume = $in

        # Stops the container if it is running, and starts it again afterwards
        with-stopped-docker-container --name $app {
            # Export sqlite database
            {
                src_volume: $data_docker_volume
                src_path: "/data/db/wallos.db"
            } | export-sqlite-database-in-volume --volume $backup_docker_volume

            # take files from volume
            "/data/db/wallos.db" | file-from-volume --src-volume $data_docker_volume --dest-volume $backup_docker_volume
        }

        {
            container_name: $container_name
            volumes: {
                config: $backup_docker_volume
            }
        }
    }
}
