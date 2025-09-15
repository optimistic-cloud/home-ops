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

def configure-hc-url [app: string] {
    let slug = $"($app)-backup"
    let run_id = (random uuid -v 4)

    configure-ping-url $slug $run_id
}


const app = "vaultwarden"
def main [--provider: string] {
    let ping_url = configure-hc-url $app

    $ping_url | with-healthcheck {

        with-docker-container --name $app {

            const docker_volume_for_export = "vaultwarden-data-export" # could be random uuid
            with-docker-volume --name $docker_volume_for_export {

                # Export sqlite database
                {
                    src_volume: "vaultwarden-data",
                    src_db: "/data/db.sqlite3",
                    dest_volume: $docker_volume_for_export,
                    dest_db: "/export/db-backup-($hc_config.run_id).sqlite3"
                } | export-sqlite-db


                # Run backup with ping
                $ping_url | with-ping {
                    (
                        ^docker run --rm -ti
                            --env-file $"($provider).env"
                            --env-file $"($app).env"
                            -v $"./($app).include.txt:/etc/restic/include.txt"
                            -v $"./($app).exclude.txt:/etc/restic/exclude.txt"
                            -v "vaultwarden-data:/data:ro"
                            -v $"($docker_volume_for_export):/export:ro"
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
                $ping_url | with-ping {
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