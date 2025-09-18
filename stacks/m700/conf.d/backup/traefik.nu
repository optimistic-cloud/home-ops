use std/log

use ./lib/with-lockfile.nu *
use ./lib/with-healthcheck.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

const app = "traefik"
const hc_slug = "traefik-backup"
const container_name = "traefik"

def main [--env-file: path, --provider-env-file: path] {
    $env_file | require | open | load-env
    
    $hc_slug | configure-hc-api

    with-lockfile $app {
        with-healthcheck {
            with-backup-docker-volume {
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
                } | backup --provider-env-file $provider_env_file
            }
        }
    }
}
