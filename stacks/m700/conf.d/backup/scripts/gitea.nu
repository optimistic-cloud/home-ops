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

    # docker exec -it gitea sh
    #docker exec -u git gitea /usr/local/bin/gitea dump --work-path /tmp --file gitea-dump.tar.gz --config /etc/gitea/app.ini --database sqlite3 --type tar.gz
    #docker cp gitea:/var/lib/gitea/gitea-dump.tar.gz /tmp/gitea/gitea-dump.tar.gz

    with-healthcheck {
        with-tmp-docker-volume {
            let export_docker_volume = $in

            let working_dir = '/tmp' | path join $app
            let dump_location = '/var/lib/gitea'
            let dump_name = 'gitea-dump.tar.gz'

            ^docker exec -u git gitea rm -f $"($dump_location)/($dump_name)"
            ^docker exec -u git gitea mkdir -p $dump_location
            print "1"
            (
                ^docker exec -u git gitea /usr/local/bin/gitea
                    dump --work-path /tmp
                    --file $dump_name
                    --config /etc/gitea/app.ini
                    --database sqlite3
                    --type tar.gz
            )

            print "2"
            mkdir $working_dir
            print $working_dir $dump_location $dump_name
            ls -la $working_dir | print
            ^docker cp gitea:/var/lib/gitea/gitea-dump.tar.gz /tmp/gitea/ | complete | print
            ls -la $working_dir | print

            print "3" 
            (
                ^docker run --rm -ti
                    -v $"($working_dir):/export:ro"
                    -v $"($export_docker_volume):/data:rw"
                    alpine sh -c $"cd /data && tar -xvzf /export/($dump_name)"
            )
            print "3.5"
            ^docker exec -u git gitea rm -f $"($dump_location)/($dump_name)" | complete | print
            print "4"
            rm -f $working_dir
            print "5"
            ^docker run --rm -ti -v $"($export_docker_volume):/data:rw" alpine ls -la /data | complete | print
            print "6"  

            # let git_commit = (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

            # # Run backup with ping
            # with-ping {
            #     (
            #         ^docker run --rm -ti
            #             --env-file $"($provider).env"
            #             --env-file $"($app).env"
            #             -v $"($export_docker_volume):/export:ro"
            #             -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
            #             -e TZ=Europe/Berlin
            #             $config.restic.docker_image --json --quiet backup /data
            #                     --skip-if-unchanged
            #                     --exclude-caches
            #                     --one-file-system
            #                     --tag=$"git_commit=($git_commit)"
            #     ) | complete
            # }

            # # Run check with ping
            # with-ping {
            #     (
            #         ^docker run --rm -ti
            #             --env-file $"($provider).env"
            #             --env-file $"($app).env"
            #             $config.restic.docker_image --json --quiet check --read-data-subset 33%
            #     ) | complete
            # }
        }
    }
}
