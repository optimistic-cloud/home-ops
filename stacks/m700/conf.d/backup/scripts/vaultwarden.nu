use std/log

use with-lockfile.nu *
use with-healthcheck.nu *
use with-docker-container.nu *
use utils.nu *

const app = "vaultwarden"
const hc_slug = "vaultwarden-backup"
const container = "vaultwarden"
const data_docker_volume = "vaultwarden-data"

const restic_docker_image = "restic/restic:0.18.0"

# Files to backup:
#   - export sqlite database from vaultwarden-data volume
#   - backup /data
#   - export env from vaultwarden container
def main [--provider: string] {
    open env.toml | load-env
    
    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-lockfile {
        with-healthcheck {
            with-backup-docker-volume {
                let backup_docker_volume = $in

                # Stops the container if it is running, and starts it again afterwards
                with-docker-container --name $app {
                    # Export sqlite database
                    {
                        src_volume: $data_docker_volume
                        dest_volume: $backup_docker_volume
                        src_path: "/data/db.sqlite3"
                    } | export-sqlite-database-in-volume
                }

                # Export env from container
                {
                    container: $container
                    dest_volume: $backup_docker_volume
                } | export-env-from-container-to-volume

                # Run backup with ping
                # Note: --one-file-system is omitted because backup data spans multiple mounts (docker volumes)
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($app).($provider).restic.env"
                            -v $"($data_docker_volume):/backup/data:ro"
                            -v $"($backup_docker_volume):/backup/config:ro"
                            -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                            -e TZ=Europe/Berlin
                            $restic_docker_image --json --quiet backup /backup
                                    --skip-if-unchanged
                                    --exclude-caches
                                    --tag=$"git_commit=(get-current-git-commit)"
                    )
                }
                
                # Run check with ping
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($app).($provider).restic.env"
                            $restic_docker_image --json --quiet check --read-data-subset 33%
                    )
                }
            }
        }
    }
}
