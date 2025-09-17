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
                # The data in this volume will be backed up under /backup/config
                let backup_docker_volume = $in

                # Stop and start container to ensure a clean state
                with-stopped-docker-container --name $app {
                    # Export sqlite database
                    {
                        src_volume: $data_docker_volume
                        src_path: "pocket-id.db"
                    } | export-sqlite-database-in-volume --volume $backup_docker_volume
                }

                # Add /app/secrets/pocket-id.encfile to backup volume
                {
                    from_container: $container_name
                    paths: ['/app/secrets/pocket-id.encfile']
                } | extract-files-from-container --volume $backup_docker_volume
                
                # Export env from container
                $container_name | export-env-from-container --volume $backup_docker_volume

                let env_file = $"($app).($provider).restic.env"

                # Run backup with ping
                with-ping {
                    {
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

def "main init" [--provider: string] { 
    $"($app).($provider).restic.env" | with-restic ["init"]
}

def "main stats" [--provider: string] { 
    $"($app).($provider).restic.env" | with-restic ["stats"] 
}

def "main ls" [--provider: string] { 
    $"($app).($provider).restic.env" | with-restic ["ls", "latest"] 
}

def "main snapshots" [--provider: string] { 
    $"($app).($provider).restic.env" | with-restic ["snapshots", "--latest", "5"] 
}

def "main restore" [--provider: string] {
    restic-restore --env-file $"($app).($provider).restic.env"
}