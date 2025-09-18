use std/log

use ./lib/with-backup-template.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

const app = "opengist"
const container_name = "opengist"
const data_docker_volume = "m700_opengist-data"

def main [--provider-env-file: path] {
    $app | with-backup-template --provider-env-file $provider_env_file {
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
