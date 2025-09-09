# closure
# function
# pipeline

use export-sqlite.nu *
use with-docker.nu *
use with-lockfile.nu *
use with-healthcheck.nu *

def test_latest_snapshot [offset: duration = 1min] {
    let snapshot_time = (restic snapshots latest --json | from json | get 0.time | into datetime)    

    if not ((date now) < ($snapshot_time + $offset)) {
        error make {msg: $"Snapshot is older than 1 minute. Snapshot time: ($snapshot_time), Current time: (date now)"}
    }
}

def main [app: string = "vaultwarden"] {
    let source_dir = $"/opt/($app)"
    let export_dir = $"/tmp/($app)/export"

    let include = [
        /opt/vaultwarden/.env
        /opt/vaultwarden/appdata
        /tmp/vaultwarden/export/db.sqlite3
    ]
    let exclude = [
        vaultwarden/appdata/db.sqlite3*
        vaultwarden/appdata/tmp
        vaultwarden/*backup*
    ] | each { |it| $"--exclude=($it)" } | str join " "

    let git_commit = git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1
    let run_id = (random uuid -v 4)
    let hc_slug = "vaultwarden-backup"

    with-lockfile $app {
        with-healthcheck $hc_slug $run_id {
            rm -rf $export_dir
            mkdir $export_dir

            with-docker $app {
                $"($source_dir)/appdata/db.sqlite3" | export-sqlite $"($export_dir)/db.sqlite3" | ignore 
            }

            restic backup ...($include) $exclude --exclude-caches --one-file-system --tag git_commit=($git_commit) | logs-to-hc $hc_slug $run_id
            test_latest_snapshot
            restic --verbose=0 --quiet check --read-data-subset 33%

            rm -rf $export_dir
        }
    }
}