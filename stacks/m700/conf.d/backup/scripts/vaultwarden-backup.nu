use std/log

use sqlite-export.nu *
use with-docker.nu *
use with-lockfile.nu *
use with-healthcheck.nu *
use restic.nu *

const app = "vaultwarden"

def main [] {
  let source_dir = '/opt' | path join $app
  let export_dir = '/tmp' | path join $app export

  let slug = $"($app)-backup"
  let run_id = (random uuid -v 4)
  let ping_url = configure-ping-url $slug $run_id

  let include_file = $"($app).include.txt"
  let exclude_file = $"($app).exclude.txt"

  try {
    send_start $ping_url

    log debug $"Start backup of ($app)."
    let git_commit = git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1

    with-lockfile $app {
       
        # Prepare export directory
        rm -rf $export_dir
        mkdir $export_dir

        # Export database
        with-docker $app {
            $"($source_dir)/appdata/db.sqlite3" | sqlite export $"($export_dir)/db.sqlite3" | ignore 
        }

        with-healthcheck $ping_url {
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

            #restic-backup $include $exclude $tags

            restic-backup2 $include_file $exclude_file $tags
        }

        with-healthcheck $ping_url {
            restic-check 33%
        }

        rm -rf $export_dir
    }
  } catch {|err|
    log error $"($app) backup failed with message: ($err.msg)"
    send_fail $ping_url

    exit 1
  }

  log debug $"Backup of ($app) was successful."
  exit 0
}
