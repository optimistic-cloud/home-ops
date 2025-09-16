
use std/log

use with-lockfile.nu *
use with-healthcheck.nu *
use with-docker.nu *
use utils.nu *

const app = "traefik"
const hc_slug = "traefik-backup"
const container_name = "traefik"

# Files to backup:
#   - backup file acme.json from traefik container
#   - backup file /etc/traefik/traefik.yml:ro from traefik container
def main [--provider: string] {
    open env.toml | load-env
    
    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-lockfile $app {
        with-healthcheck {
            with-backup-docker-volume {
                let backup_docker_volume = $in

                # Add acme.json to backup volume
                {
                    from_container: $container_name
                    file_path_to_extract: /acme.json
                } | extract-file-from-container --volume $backup_docker_volume

                # Add traefik.yml to backup volume
                {
                    from_container: $container_name
                    file_path_to_extract: /etc/traefik/traefik.yml
                } | extract-file-from-container --volume $backup_docker_volume

                # Export env from container
                $container_name | export-env-from-container --volume $backup_docker_volume

                let env_file = $"($app).($provider).restic.env"

                # Run backup with ping
                with-ping {
                    {
                        config: $backup_docker_volume
                    } | restic-backup --env-file $env_file
                }
                
                # Run check with ping
                with-ping {
                    restic-check --env-file $env_file
                }
            }
        }
    }
}
