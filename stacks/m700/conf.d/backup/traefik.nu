use std/log

use ./lib/with-backup-template.nu *
use ./lib/with-docker.nu *
use ./lib.nu *

const app = "traefik"
const container_name = "traefik"

def main [...provider_env_files: path] {
    $app | with-backup-template --provider-env-files $provider_env_files {
        let backup_docker_volume = $in
    
        # Add files to backup volume
        {
            from_container: $container_name
            paths: ['/acme.json', '/etc/traefik/traefik.yml']
        } | extract-files-from-container --volume $backup_docker_volume
    
        {
            container_name: $container_name
            volumes: {
                config: $backup_docker_volume
            }
        }
    }
}
