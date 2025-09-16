use std/log

use with-healthcheck.nu *
use with-docker-container.nu *

const app = "vaultwarden"
const hc_slug = "vaultwarden-backup"
const data_docker_volume = "vaultwarden-data"

const restic_docker_image = "restic/restic:0.18.0"

def main [--provider: string] {
    open env.toml | load-env
    
    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-healthcheck {
        with-docker-container --name $app {

            with-tmp-docker-volume {
                let export_docker_volume = $in

                # Export sqlite database
                (
                    ^docker run --rm 
                        -v $"($data_docker_volume):/data:ro"
                        -v $"($export_docker_volume):/export:rw"
                        alpine/sqlite /data/db.sqlite3 ".backup '/export/db.sqlite3'"
                )
                (
                    ^docker run --rm 
                        -v $"($export_docker_volume):/export:rw"
                        alpine/sqlite /export/db.sqlite3 "PRAGMA integrity_check;" | ignore
                )

                let git_commit = (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

                # Run backup with ping
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($app).($provider).restic.env"
                            -v $"($data_docker_volume):/backup/data:ro"
                            -v $"($export_docker_volume):/backup/export:ro"
                            -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                            -e TZ=Europe/Berlin
                            $restic_docker_image --json --quiet backup /backup
                                    --skip-if-unchanged
                                    --exclude-caches
                                    --one-file-system
                                    --tag=$"git_commit=($git_commit)"
                    ) | complete
                }

                # Run check with ping
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($app).($provider).restic.env"
                            $restic_docker_image --json --quiet check --read-data-subset 33%
                    ) | complete
                }
            }
        }
    }
}
