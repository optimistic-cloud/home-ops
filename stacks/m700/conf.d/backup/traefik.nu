use std/log

use ./lib/with-backup-template.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

const app = "traefik"
const container_name = "traefik"

def main [--provider-env-file: path] {
    $app | with-backup-template --provider-env-file $provider_env_file {
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
