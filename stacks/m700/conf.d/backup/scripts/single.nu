use std/log

use export-sqlite.nu *
use with-docker.nu *
use with-lockfile.nu *
use with-healthcheck.nu *
use restic.nu *

def main [app: string = "vaultwarden"] {
    let source_dir = '/opt' | path join $app
    let export_dir = '/tmp' | path join $app export
    let run_id = (random uuid -v 4)
    let hc_slug = $"($app)-backup"
    let git_commit = git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1

    with-lockfile $app {
       
        # Prepare export directory
        rm -rf $export_dir
        mkdir $export_dir

        # Export database
        with-docker $app {
            $"($source_dir)/appdata/db.sqlite3" | export-sqlite $"($export_dir)/db.sqlite3" | ignore 
        }

        with-healthcheck $hc_slug $run_id {
            let backup_cmd = create_restic_backup_cmd $hc_slug $run_id

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
            let tags = [
                $"git_commit=($git_commit)"
            ]

            do $backup_cmd $include $exclude $tags
        }

        with-healthcheck $hc_slug $run_id {
            let check_cmd = create_restic_check_cmd $hc_slug $run_id
            do $check_cmd 33%
        }

        rm -rf $export_dir
    }
}
