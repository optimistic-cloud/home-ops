use std/log

use ./lib/with-backup-template.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

const app = "pocket-id"
const container_name = "pocket-id"
const data_docker_volume = "m700_pocket-id-data"

def main [...provider_env_files: path] {
    $app | with-backup-template --provider-env-files $provider_env_files {
        # The data in this volume will be backed up under /backup/config
        let backup_docker_volume = $in
    
        # Stop and start container to ensure a clean state
        with-stopped-docker-container --name $app {
            # Export sqlite database
            {
                src_volume: $data_docker_volume
                src_path: "pocket-id.db"
            } | export-sqlite-database-in-volume --volume $backup_docker_volume
        }
    
        # Add /app/secrets/pocket-id.encfile to backup volume
        {
            from_container: $container_name
            paths: ['/app/secrets/pocket-id.encfile']
        } | extract-files-from-container --volume $backup_docker_volume
        
        {
            container_name: $container_name
            volumes: {
                data: $data_docker_volume
                config: $backup_docker_volume
            }
        }
    }
}
