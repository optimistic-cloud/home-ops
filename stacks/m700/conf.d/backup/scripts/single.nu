use std/log

use export-sqlite.nu *
use with-docker.nu *
use with-lockfile.nu *
use with-healthcheck.nu *
use restic.nu *

def main [app: string = "vaultwarden"] {
    let source_dir = '/opt' | path join $app
    let export_dir = '/tmp' | path join $app export

    let include = [
        /opt/vaultwarden/.env
        /opt/vaultwarden/appdata
        /tmp/vaultwarden/export/db.sqlite3
    ]
    let exclude = [
        vaultwarden/appdata/db.sqlite3*
        vaultwarden/appdata/tmp
        vaultwarden/*backup*
    ] 

    
    let run_id = (random uuid -v 4)
    let hc_slug = "vaultwarden-backup"

    with-lockfile $app {
        with-healthcheck $hc_slug $run_id {
            rm -rf $export_dir
            mkdir $export_dir

            with-docker $app {
                $"($source_dir)/appdata/db.sqlite3" | export-sqlite $"($export_dir)/db.sqlite3" | ignore 
            }



            do $restic-backup $include $exclude
            restic --verbose=0 --quiet check --read-data-subset 33%

            # Debug snapshot details
            # restic snapshots latest
            # restic ls latest --long --recursive

            rm -rf $export_dir
        }
    }
}