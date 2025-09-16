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
                let dump_name = 'gitea-dump.tar.gz'

                ^docker exec -u git gitea rm -f $"($dump_location)/($dump_name)"
                ^docker exec -u git gitea mkdir -p $dump_location
                (
                    ^docker exec -u git gitea /usr/local/bin/gitea
                        dump --work-path /tmp
                        --file $dump_name
                        --config /etc/gitea/app.ini
                        --database sqlite3
                        --type tar.gz
                ) | ignore

                {
                    container: gitea
                    src_path: $"($dump_location)/($dump_name)"
                } | copy-file-from-container-to-volume --volume $backup_docker_volume {
                    let dir = $in

                    print $dir
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

                # Run backup with ping
                with-ping {
                    let volumes = {
                        config: $backup_docker_volume
                    }
                    $"($app).($provider).restic.env" | restic-backup $volumes
                }

                # Run check with ping
                with-ping {
                    $"($app).($provider).restic.env" | restic-check
                }
            }
        }
    }
}