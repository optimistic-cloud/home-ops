use std/log

use ./lib/with-backup-template-many.nu *
use ./lib/with-docker.nu *
use ./lib/lib.nu *

const app = "opengist"
const container_name = "opengist"
const data_docker_volume = "opengist-data"

def main [...provider_env_files: path] {
    $app | with-backup-template --provider-env-files $provider_env_files {
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
        }
    }
}
