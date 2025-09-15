use std/log

use with-healthcheck.nu *
use sqlite-export.nu *
use with-docker-container.nu *

const app = "opengist"

def main [--provider: string] {
    let config = open backup.toml

    const data_docker_volume = $config.$"($app)".data_volume

    $config.$"($app)".hc_slug | configure-hc-api $config.hc.ping_key

    with-healthcheck {
        with-docker-container --name $app {

            with-tmp-docker-volume {
                let export_docker_volume = $in

                # Export sqlite database
                {
                    src_volume: $data_docker_volume,
                    src_db: $"/data/($app).db",
                    dest_volume: $export_docker_volume,
                    dest_db: $"/export/($app).db"
                } | export-sqlite-db

                let git_commit = (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

                # Run backup with ping
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($provider).env"
                            --env-file $"($app).env"
                            -v $"($data_docker_volume):/data:ro"
                            -v $"($export_docker_volume):/export:ro"
                            -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                            -e TZ=Europe/Berlin
                            $config.restic.docker_image --json --quiet backup /data /export
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
                            --env-file $"($provider).env"
                            --env-file $"($app).env"
                            $config.restic.docker_image --json --quiet check --read-data-subset 33%
                    ) | complete
                }
            }
        }
    }
}
