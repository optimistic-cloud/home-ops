use std/log

use with-healthcheck.nu *
use with-docker-container.nu *
use utils.nu *

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
                let config_docker_volume = $in

                # Export sqlite database
                {
                    src_volume: "vaultwarden-data"
                    dest_volume: $in
                    src_path: "/data/db.sqlite3"
                    dest_path: "/export/db.sqlite3"
                } | export-sqlite-database-in-volume

                "example.env.toml" | add-file-to-volume $config_docker_volume

                let git_commit = (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

                # Run backup with ping
                # Note: --one-file-system is omitted because backup data spans multiple mounts (docker volumes)
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($app).($provider).restic.env"
                            -v $"($data_docker_volume):/backup/data:ro"
                            -v $"($config_docker_volume):/backup/config:ro"
                            -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                            -e TZ=Europe/Berlin
                            $restic_docker_image --json --quiet backup /backup
                                    --skip-if-unchanged
                                    --exclude-caches
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
