use std/log

use with-healthcheck.nu *
use with-docker-container.nu *

const app = "pocket-id"
const hc_slug = "pocket-id-backup"
const data_docker_volume = "pocket-id-data"

const restic_docker_image = "restic/restic:0.18.0"

# Files to backup:
#   - backup file /app/secrets/pocket-id.encfile from pocket-id container
#   - export sqlite database /data/pocket-id.db sqlite from pocket-id-data volume
#   - backup /app/data
#   - export env from pocket-id container
def main [--provider: string] {
    open env.toml | load-env

    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-healthcheck {
        with-tmp-docker-volume {
            # Stop and start container to ensure a clean state
            with-docker-container --name $app {

                let export_docker_volume = $in

                # Export sqlite database
                (
                    ^docker run --rm 
                        -v $"($data_docker_volume):/data:ro"
                        -v $"($export_docker_volume):/export:rw"
                        alpine/sqlite $"/data/($app).db" $".backup '/export/($app).db'"
                )
                (
                    ^docker run --rm 
                        -v $"($export_docker_volume):/export:rw"
                        alpine/sqlite $"/export/($app).db" "PRAGMA integrity_check;" | ignore
                )
            }

            # TODO: refactor
            # Copy /app/secrets/pocket-id.encfile to export volume
            # let working_dir = '/tmp' | path join $app
            # mkdir $working_dir
            # ^docker cp pocket-id:/app/secrets/pocket-id.encfile /tmp/pocket-id/ | ignore


            (
                ^docker run --rm 
                    -v $"($data_docker_volume):/data:ro"
                    -v $"($export_docker_volume):/export:rw"
                    alpine sh -c "cp /data/secrets/pocket-id.encfile /export/pocket-id.encfile"
            ) | ignore

            let git_commit = (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

            # Run backup with ping
            with-ping {
                (
                    ^docker run --rm -ti
                        --env-file $"($app).($provider).restic.env"
                        -v $"($data_docker_volume):/data:ro"
                        -v $"($export_docker_volume):/export:ro"
                        -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                        -e TZ=Europe/Berlin
                        $restic_docker_image --json --quiet backup /data /export
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
