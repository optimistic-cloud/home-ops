use std/log

use with-healthcheck.nu *
use sqlite-export.nu *
use with-docker-container.nu *

const app = "gitea"

def main [--provider: string] {
    let config = open backup.toml

    let slug = $config | get $app | get hc_slug
    let data_docker_volume = $config | get $app | get data_volume

    $slug | configure-hc-api $config.hc.ping_key

    with-healthcheck {
        with-tmp-docker-volume {
            let export_docker_volume = $in

            let working_dir = '/tmp' | path join $app
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
            )

            mkdir $working_dir
            ^docker cp gitea:/var/lib/gitea/gitea-dump.tar.gz /tmp/gitea/ | complete | print

            (
                ^docker run --rm -ti
                    -v $"($working_dir):/export:ro"
                    -v $"($export_docker_volume):/data:rw"
                    alpine sh -c $"cd /data && tar -xvzf /export/($dump_name)"
            )
            ^docker exec -u git gitea rm -f $"($dump_location)/($dump_name)" | complete | print
            rm -rf $working_dir

            let git_commit = (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

            # Run backup with ping
            with-ping {
                (
                    ^docker run --rm -ti
                        --env-file $"($provider).env"
                        --env-file $"($app).env"
                        -v $"($export_docker_volume):/export:ro"
                        -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                        -e TZ=Europe/Berlin
                        $config.restic.docker_image --json --quiet backup /export
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
                        --env-file $"($app).env"
                        $config.restic.docker_image --json --quiet check --read-data-subset 33%
                ) | complete
            }
        }
    }
}
