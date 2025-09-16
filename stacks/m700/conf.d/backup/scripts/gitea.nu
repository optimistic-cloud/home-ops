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
                ) | ignore

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

                # not ready to use
                #{
                #    container: gitea
                #    dest_volume: $backup_docker_volume
                #    src_path: $in.src_path
                #    dest_path: $in.dest_path
                #} | copy-file-from-container-to-volume


                # let working_dir = '/tmp' | path join $app
                # mkdir $working_dir
                # ^docker cp gitea:/var/lib/gitea/gitea-dump.tar.gz /tmp/gitea/ | ignore

                # (
                #     ^docker run --rm -ti
                #         -v $"($working_dir):/export:ro"
                #         -v $"($backup_docker_volume):/data:rw"
                #         alpine sh -c $"cd /data && tar -xvzf /export/($dump_name)"
                # ) | ignore
                # ^docker exec -u git gitea rm -f $"($dump_location)/($dump_name)" | ignore
                # rm -rf $working_dir

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