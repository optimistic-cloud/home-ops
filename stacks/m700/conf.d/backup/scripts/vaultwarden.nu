use std/log

use with-healthcheck.nu *
use with-docker-container.nu *

const app = "vaultwarden"

# nu vaultwarden.nu --provider blaze
#   blaze.env
#   vaultwarden.blaze.restic.env
# nu vaultwarden.nu --provider aws
def main [--provider: string] {
    let config = open backup.toml

    let slug = $config | get $app | get hc_slug
    let data_docker_volume = $config | get $app | get data_volume

    $slug | configure-hc-api $config.hc.ping_key

    with-healthcheck {
        with-docker-container --name $app {

            with-tmp-docker-volume {
                let export_docker_volume = $in

                # Export sqlite database
                {
                    src_volume: $data_docker_volume,
                    src_db: "/data/db.sqlite3",
                    dest_volume: $export_docker_volume,
                    dest_db: "/export/db.sqlite3"
                } | export-sqlite-db

                let git_commit = (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

                # Run backup with ping
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($provider).env"
                            --env-file $"($app).($provider).restic.env"
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
                            --env-file $"($app).($provider).restic.env"
                            $config.restic.docker_image --json --quiet check --read-data-subset 33%
                    ) | complete
                }
            }
        }
    }
}
