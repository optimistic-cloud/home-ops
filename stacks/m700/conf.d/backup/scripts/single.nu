use std/log

use export-sqlite.nu *
use with-docker.nu *
use with-lockfile.nu *
use with-healthcheck.nu *
use utils.nu *

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

            let res = {|i,e|
                let git_commit = git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1
                let exclude_as_string = $e | each { |it| $"--exclude=($it)" } | str join " "
                let out = ^restic backup ...($i) $exclude_as_string --exclude-caches --one-file-system --tag git_commit=($git_commit) | complete

                if $out.exit_code != 0 {
                    error make {msg: "Restic backup command failed", code: $out.exit_code, stderr: $out.stderr}
                }

                $out.stdout | logs-to-hc $hc_slug $run_id

                assert_backup_created
            }

            #restic backup ...($include) $exclude --exclude-caches --one-file-system --tag git_commit=($git_commit) | logs-to-hc $hc_slug $run_id
            
            do $res $include $exclude
            restic --verbose=0 --quiet check --read-data-subset 33%

            # Debug snapshot details
            # restic snapshots latest
            # restic ls latest --long --recursive

            rm -rf $export_dir
        }
    }
}