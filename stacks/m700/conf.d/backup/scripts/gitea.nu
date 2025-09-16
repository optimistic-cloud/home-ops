use std/log

use with-lockfile.nu *
use with-healthcheck.nu *
use with-docker.nu *
use utils.nu *

const app = "gitea"
const hc_slug = "gitea-backup"
const container_name = "gitea"

# Files to backup:
#   - export dump from gitea container
#   - export env from gitea container
def main [--provider: string] {
    open env.toml | load-env

    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-lockfile $app {
        with-healthcheck {
            with-backup-docker-volume {
                let backup_docker_volume = $in

                # Create gitea-dump.tar.gz
                # https://docs.gitea.com/administration/backup-and-restore
                do {
                    let dump_location = '/var/lib/gitea'
                    let gitea_archive = 'gitea-dump.tar.gz'

                    # remove old dump, create new dump 
                    ^docker exec -u git gitea rm -f $"($dump_location)/($gitea_archive)"
                    ^docker exec -u git gitea mkdir -p $dump_location
                    (
                        ^docker exec -u git gitea /usr/local/bin/gitea
                            dump --work-path /tmp
                            --file $gitea_archive
                            --config /etc/gitea/app.ini
                            --database sqlite3
                            --type tar.gz
                    )
                }

                # Add contents of gitea-dump.tar.gz to backup volume
                do {
                    {
                        container: gitea
                        src_path: $"($dump_location)/($gitea_archive)"
                    } | copy-file-from-container-to-volume --volume $backup_docker_volume --sub-path "gitea-dump" {
                        let tmp_dir = $in

                        # gitea.tar.gz
                        let archive = $"($tmp_dir)/($gitea_archive)"

                        # extract in-place and remove the archive
                        ^tar -xzf $archive -C $tmp_dir | ignore
                        ^rm -f $archive | ignore

                        $tmp_dir
                    }
                }

                # Export env from container
                $container_name | export-env-from-container --volume $backup_docker_volume

                let env_file = $"($app).($provider).restic.env"

                # Run backup with ping
                with-ping {
                    {
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