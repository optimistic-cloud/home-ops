use std/log

use with-healthcheck.nu *
use sqlite-export.nu *
use with-docker-container.nu *

def export-sqlite-db []: record -> nothing {
    let config = $in

    (
        ^docker run --rm 
            -v $"($config.src_volume):/data:ro"
            -v $"($config.dest_volume):/export:rw"
            alpine/sqlite $'($config.src_db)' $".backup '($config.dest_db)'"
    )
    (
        ^docker run --rm 
            -v $"($config.dest_volume):/export:rw"
            alpine/sqlite $'($config.dest_db)' "PRAGMA integrity_check;"
    )
}

const app = "vaultwarden"

def main [--provider: string] {
    [$app, 'backup'] | str join '-' | configure-hc-api

    with-healthcheck {
        with-docker-container --name $app {

            with-tmp-docker-volume {
                let tmp_docker_volume = $in

                # Export sqlite database
                {
                    src_volume: "vaultwarden-data",
                    src_db: "/data/db.sqlite3",
                    dest_volume: $tmp_docker_volume,
                    dest_db: "/export/db.sqlite3"
                } | export-sqlite-db


                # Run backup with ping
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($provider).env"
                            --env-file $"($app).env"
                            -v $"./($app).include.txt:/etc/restic/include.txt"
                            -v $"./($app).exclude.txt:/etc/restic/exclude.txt"
                            -v "vaultwarden-data:/data:ro"
                            -v $"($tmp_docker_volume):/export:ro"
                            -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
                            restic/restic --json --quiet backup
                                    --files-from /etc/restic/include.txt
                                    --exclude-file /etc/restic/exclude.txt
                                    --skip-if-unchanged
                                    --exclude-caches
                                    --one-file-system
                                    --tag=test
                    ) | complete
                }

                # Run check with ping
                with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($provider).env"
                            --env-file $"($app).env"
                            restic/restic --json --quiet check --read-data-subset 33%
                    ) | complete
                }
            }
        }
    }
}