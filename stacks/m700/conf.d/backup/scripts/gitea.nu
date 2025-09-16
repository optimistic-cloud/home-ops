use std/log

use with-lockfile.nu *
use with-healthcheck.nu *
use with-docker.nu *
use utils.nu *

const app = "gitea"
const hc_slug = "gitea-backup"
const container_name = "gitea"

def main [--provider: string] {
    open env.toml | load-env

    $hc_slug | configure-hc-api $env.HC_PING_KEY

    with-lockfile $app {
        with-healthcheck {
            with-backup-docker-volume {
                let backup_docker_volume = $in

                let dump_location = '/var/lib/gitea'
                let gitea_archive = 'gitea-dump.tar.gz'

                # Create gitea-dump.tar.gz
                # https://docs.gitea.com/administration/backup-and-restore
                do {
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
                        from_container: $container_name
                        file_path_to_extract: $"($dump_location)/($gitea_archive)"
                    } | extract-file-from-container --volume $backup_docker_volume --sub-path "gitea-dump" {
                        let tmp_dir = $in

                        # gitea.tar.gz
                        let archive = $"($tmp_dir)/($gitea_archive)"
                        print $archive

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

def "main init" [--provider: string] {
    let env_file = $"($app).($provider).restic.env"

    restic-init --env-file $env_file
}

def "main ls" [--provider: string] {
    let env_file = $"($app).($provider).restic.env"

    restic-ls --env-file $env_file
}

export def restic-snapshots [--env-file: path, --latest: int = 5]: nothing -> nothing {
  let envs = $env_file | path expand

  ^docker run --rm -ti --env-file $envs $restic_docker_image snapshots --latest $latest
}