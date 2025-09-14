use std/log

use with-healthcheck.nu *
use sqlite-export.nu *
use with-docker-container.nu *


def backup [provider: string, slug: string, run_id: string] {
    #-v ./vw-backup/db.sqlite3:/export/db.sqlite3 ??? working dir

    # try to export database and leave it in volume for backup
    with-ping $slug $run_id {
        (
            ^docker run --rm -ti
                --env-file $"($provider).env"
                --env-file "vaultwarden.env"
                -v ./vaultwarden.include.txt:/etc/restic/include.txt
                -v ./vaultwarden.exclude.txt:/etc/restic/exclude.txt
                -v vaultwarden-data:/data:ro
                -v $env.HOME/.cache/restic:/root/.cache/restic
                -e TZ=Europe/Berlin
                restic/restic --json --quiet backup
                        --files-from /etc/restic/include.txt
                        --exclude-file /etc/restic/exclude.txt
                        --skip-if-unchanged
                        --exclude-caches
                        --one-file-system
                        --tag=test
        )
    }
}

def check [provider: string, slug: string, run_id: string] {
    with-ping $slug $run_id {
        (
            ^docker run --rm -ti
                --env-file $"($provider).env"
                --env-file "vaultwarden.env"
                -e TZ=Europe/Berlin
                restic/restic --json --quiet check --read-data-subset 33%
        )
    }
}

def main [app = "vaultwarden", --provider: string] {
    let slug = $"($app)-backup"
    let run_id = (random uuid -v 4)

    with-healthcheck $slug $run_id {

        with-docker-container --container_name $app {

            with-docker-volume --volume_name vaultwarden-data-export {

                # Export sqlite database
                let export_config = {
                    src_volume: 'vaultwarden-data',
                    dest_volume: $in,
                    src_db: ('/data' | path join 'db.sqlite3'),
                    dest_db: ('/export' | path join 'db.sqlite3'),
                }
                (
                    ^docker run --rm 
                        -v $"($export_config.src_volume):/data:ro"
                        -v $"($export_config.dest_volume):/export:rw"
                        alpine/sqlite $'($export_config.src_db)' $".backup '($export_config.dest_db)'"
                )
                (
                    ^docker run --rm 
                        -v $"($export_config.dest_volume):/export:rw"
                        alpine/sqlite $'($export_config.dest_db)' "PRAGMA integrity_check;"
                )

                # Run backup with ping
                with-ping $slug $run_id {
                    (
                        ^docker run --rm -ti
                            --env-file $"($provider).env"
                            --env-file $"($app).env"
                            -v $"./($app).include.txt:/etc/restic/include.txt"
                            -v $"./($app).exclude.txt:/etc/restic/exclude.txt"
                            -v vaultwarden-data:/data:ro
                            -v vaultwarden-data-export:/export:ro
                            -v $env.HOME/.cache/restic:/root/.cache/restic
                            restic/restic --json --quiet backup
                                    --files-from /etc/restic/include.txt
                                    --exclude-file /etc/restic/exclude.txt
                                    --skip-if-unchanged
                                    --exclude-caches
                                    --one-file-system
                                    --tag=test
                    )
                }

                # Run check with ping
                with-ping $slug $run_id {
                    (
                        ^docker run --rm -ti
                            --env-file $"($provider).env"
                            --env-file "vaultwarden.env"
                            -v ./vaultwarden.include.txt:/etc/restic/include.txt
                            -v ./vaultwarden.exclude.txt:/etc/restic/exclude.txt
                            -v vaultwarden-data:/data:ro
                            -v $env.HOME/.cache/restic:/root/.cache/restic
                            -e TZ=Europe/Berlin
                            restic/restic --json --quiet backup
                                    --files-from /etc/restic/include.txt
                                    --exclude-file /etc/restic/exclude.txt
                                    --skip-if-unchanged
                                    --exclude-caches
                                    --one-file-system
                                    --tag=test
                    )
                }
            }
        }
    }
}