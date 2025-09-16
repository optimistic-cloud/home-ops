use std/log

use with-healthcheck.nu *
use with-docker-container.nu *
use utils.nu *

const app = "pocket-id"
const hc_slug = "pocket-id-backup"
const container = "pocket-id"
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

        with-backup-docker-volume {
            print 11
            let backup_docker_volume = $in
print 22
            # Stop and start container to ensure a clean state
            with-docker-container --name $app {
                print 33
                # Export sqlite database
                let config = {
                    src_volume: $data_docker_volume
                    dest_volume: $backup_docker_volume
                    src_path: "/app/data/pocket-id.db"
                } 
                print 34 $config
                $config | export-sqlite-database-in-volume
                print 44
            }
print 55
            # TODO: refactor
            # Copy /app/secrets/pocket-id.encfile to export volume
            # let working_dir = '/tmp' | path join $app
            # mkdir $working_dir
            # ^docker cp pocket-id:/app/secrets/pocket-id.encfile /tmp/pocket-id/ | ignore


            (
                ^docker run --rm 
                    -v $"($data_docker_volume):/data:ro"
                    -v $"($backup_docker_volume):/export:rw"
                    alpine sh -c "cp /app/secrets/pocket-id.encfile /export/pocket-id.encfile"
            ) | ignore
print 66
            # Export env from container
            {
                container: $container
                dest_volume: $backup_docker_volume
            } | export-env-from-container-to-volume

            # Run backup with ping
            with-ping {
                (
                    ^docker run --rm -ti
                        --env-file $"($app).($provider).restic.env"
                        -v $"($data_docker_volume):/data:ro"
                        -v $"($backup_docker_volume):/export:ro"
                        -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                        -e TZ=Europe/Berlin
                        $restic_docker_image --json --quiet backup /data /export
                                --skip-if-unchanged
                                --exclude-caches
                                --one-file-system
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
