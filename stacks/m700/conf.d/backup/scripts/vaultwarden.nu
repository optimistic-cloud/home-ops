use std/log

use with-healthcheck.nu *
use sqlite-export.nu *
use with-docker-container.nu *

const app = "vaultwarden"
const data_docker_volume = "vaultwarden-data"
const restic_image = "restic/restic:0.18.0"

def main [--provider: string] {
    [$app, 'backup'] | str join '-' | configure-hc-api

    with-healthcheck {
        with-docker-container --name $app {

            with-tmp-docker-volume {
                let backup_docker_volume = $in

                # Export sqlite database
                {
                    src_volume: $data_docker_volume,
                    src_db: "/data/db.sqlite3",
                    dest_volume: $backup_docker_volume,
                    dest_db: "/export/db.sqlite3"
                } | export-sqlite-db

                (
                    ^docker run --rm -ti
                        -v $"($data_docker_volume):/app:ro"
                        -v $"($backup_docker_volume):/data:rw"
                        alpine cp -r /app/ /data/
                )

                let git_commit = (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

                # Run backup with ping
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($provider).env"
                            --env-file $"($app).env"
                            -v $"($backup_docker_volume):/data:ro"
                            -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                            $restic_image --json --quiet backup /data
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