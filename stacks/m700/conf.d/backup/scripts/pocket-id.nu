use std/log

use with-lockfile.nu *
use with-healthcheck.nu *
use with-docker.nu *
use utils.nu *

const app = "pocket-id"
const hc_slug = "pocket-id-backup"
const container_name = "pocket-id"
const data_docker_volume = "pocket-id-data"

# Files to backup:
#   - backup file /app/secrets/pocket-id.encfile from pocket-id container
#   - ok export sqlite database /data/pocket-id.db sqlite from pocket-id-data volume
#   - OK backup /app/data
#   - OK export env from pocket-id container
def main [--provider: string] {
    open env.toml | load-env

    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-lockfile $app {
        with-healthcheck {
            with-backup-docker-volume {
                let backup_docker_volume = $in

                # Stop and start container to ensure a clean state
                with-stopped-docker-container --name $app {
                    # Export sqlite database
                    {
                        src_volume: $data_docker_volume
                        src_path: "/app/data/pocket-id.db"
                    } | export-sqlite-database-in-volume --volume $backup_docker_volume
                }

                # TODO: refactor
                # Copy /app/secrets/pocket-id.encfile to export volume
                # let working_dir = '/tmp' | path join $app
                # mkdir $working_dir
                # ^docker cp pocket-id:/app/secrets/pocket-id.encfile /tmp/pocket-id/ | ignore


                
                # TODO: not working yet use copy-file-from-container-to-volume
                (
                    ^docker run --rm 
                        -v $"($data_docker_volume):/data:ro"
                        -v $"($backup_docker_volume):/export:rw"
                        alpine sh -c "cp /app/secrets/pocket-id.encfile /export/pocket-id.encfile"
                ) | ignore

                # Export env from container
                $container_name | export-env-from-container --volume $backup_docker_volume


                let env_file = $"($app).($provider).restic.env"

                # Run backup with ping
                with-ping {
                    let volumes = {
                        data: $data_docker_volume
                        config: $backup_docker_volume
                    } | restic-backup --env-file $env_file
                }
                
                # Run check with ping
                with-ping {
                    restic-check --env-file $env_file
                }
            }
        }
    }
}
