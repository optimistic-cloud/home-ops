use std/log

use with-healthcheck.nu *
use with-docker-container.nu *
use utils.nu *

const app = "opengist"
const hc_slug = "opengist-backup"
const data_docker_volume = "opengist-data"

const restic_docker_image = "restic/restic:0.18.0"

def main [--provider: string] {
    open env.toml | load-env

    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-healthcheck {
        with-docker-container --name $app {

            with-tmp-docker-volume {
                let export_docker_volume = $in

                # Export sqlite database
                {
                    src_volume: "vaultwarden-data"
                    dest_volume: $in
                    src_path: "/data/opengist.db"
                    dest_path: "/export/opengist.db"
                } | export-sqlite-database-in-volume

                # Run backup with ping
                # Note: --one-file-system is omitted because backup data spans multiple mounts (docker volumes)
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
                                    --tag=$"git_commit=(get-current-git-commit)"
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
