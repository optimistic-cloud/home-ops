use std/log

use with-healthcheck.nu *
use sqlite-export.nu *
use with-docker-container.nu *

const app = "opengist"
const data_docker_volume = "opengist-data"
const restic_image = "restic/restic:0.18.0"

def main [--provider: string] {
    [$app, 'backup'] | str join '-' | configure-hc-api

    with-healthcheck {
        with-docker-container --name $app {

            with-tmp-docker-volume {
                let tmp_docker_volume = $in

                # Export sqlite database
                {
                    src_volume: $data_docker_volume,
                    src_db: $"/opengist/($app).db",
                    dest_volume: $tmp_docker_volume,
                    dest_db: $"/export/($app).db"
                } | export-sqlite-db

                let git_commit = (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

                # Run backup with ping
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($provider).env"
                            --env-file $"($app).env"
                            -v $"./($app).include.txt:/etc/restic/include.txt"
                            -v $"./($app).exclude.txt:/etc/restic/exclude.txt"
                            -v $"($data_docker_volume):/data:ro"
                            -v $"($tmp_docker_volume):/export:ro"
                            -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                            $restic_image --json --quiet backup
                                    --files-from /etc/restic/include.txt
                                    --exclude-file /etc/restic/exclude.txt
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
                            $restic_image --json --quiet check --read-data-subset 33%
                    ) | complete
                }
            }
        }
    }
}