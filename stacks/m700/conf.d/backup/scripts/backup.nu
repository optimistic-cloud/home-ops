use std/log

use with-healthcheck.nu *
use sqlite-export.nu *
use with-docker-container.nu *

def export-sqlite-database [] {
    print "Exporting SQLite database..."
    let src_db_in_container = '/data' | path join 'db.sqlite3'
    let dest_db_in_container = '/export' | path join 'db.sqlite3'

    print $"Source DB: ($src_db_in_container)"
    print $"Destination DB: ($dest_db_in_container)"

    #src_db_in_container | sqlite export2 "vaultwarden-data" $dest_db_in_container
}

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

        let export_dir = '/tmp' | path join $app export

        with-docker-container --container_name $app {
            print "test"
            # Export sqlite database
            export-sqlite-database 

            # Run backup
            #backup $provider $slug $run_id

            # Run check
            #check $provider $slug $run_id
        }
    }
}