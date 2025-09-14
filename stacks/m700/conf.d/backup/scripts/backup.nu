use std/log

use with-healthcheck.nu *
use sqlite-export.nu *

def export-sqlite-database []: string -> nothing {
    let src_db_in_container = '/data' | path join 'db.sqlite3'
    let dest_db_in_container = '/export' | path join 'db.sqlite3'

    src_db_in_container | sqlite export2 $dest_db_in_container
}

def backup [provider: string, slug: string, run_id: string] {
    with-ping $slug $run_id {
        (
            ^docker run --rm -ti
                --env-file $"($provider).env"
                --env-file "vaultwarden.env"
                -v ./($app).include.txt:/etc/restic/include.txt
                -v ./($app).exclude.txt:/etc/restic/exclude.txt
                -v ./vw-backup/db.sqlite3:/export/db.sqlite3 ??? working dir
                -v vaultwarden-data:/data:ro
                -v $HOME/.cache/restic:/root/.cache/restic
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

def main [app: string = "vaultwarden", --provider: string] {
    const slug = $"($app)-backup"
    const run_id = (random uuid -v 4)

    with-healthcheck $slug $run_id {

        let export_dir = '/tmp' | path join $app export

        with-docker-container --container_name $app {

            # Export sqlite database
            export-sqlite-database 

            # Run backup
            backup $provider $slug $run_id

            # Run check
            check $provider $slug $run_id
        }
    }
}