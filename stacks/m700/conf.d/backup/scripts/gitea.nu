use std/log

use with-healthcheck.nu *
use with-stopped-docker-container.nu *
use utils.nu *

const app = "gitea"
const hc_slug = "gitea-backup"
const container = "gitea"

const restic_docker_image = "restic/restic:0.18.0"

# Files to backup:
#   - export dump from gitea container
#   - export env from gitea container
def main [--provider: string] {
    open env.toml | load-env

    $hc_slug | configure-hc-api $env.HC_PING_KEY

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

            # not ready to use
            #{
            #    container: gitea
            #    dest_volume: $backup_docker_volume
            #    src_path: $in.src_path
            #    dest_path: $in.dest_path
            #} | copy-file-from-container-to-volume


            let working_dir = '/tmp' | path join $app
            mkdir $working_dir
            ^docker cp gitea:/var/lib/gitea/gitea-dump.tar.gz /tmp/gitea/ | ignore

            (
                ^docker run --rm -ti
                    -v $"($working_dir):/export:ro"
                    -v $"($backup_docker_volume):/data:rw"
                    alpine sh -c $"cd /data && tar -xvzf /export/($dump_name)"
            ) | ignore
            ^docker exec -u git gitea rm -f $"($dump_location)/($dump_name)" | ignore
            rm -rf $working_dir

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
                        -v $"($backup_docker_volume):/export:ro"
                        -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                        -e TZ=Europe/Berlin
                        $restic_docker_image --json --quiet backup /export
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
