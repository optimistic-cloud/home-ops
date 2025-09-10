use std/log

use sqlite-export.nu *
use with-docker.nu *
use with-lockfile.nu *
use with-healthcheck.nu *
use restic.nu *

export def main [app: string, operation: closure] {
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

        print "a"
        do $operation
        print "b"

        with-healthcheck $ping_url {
            let tags = [
                $"git_commit=($git_commit)"
            ]
            restic-backup $include_file $exclude_file $tags
        }

        with-healthcheck $ping_url {
            restic-check 33%
        }

        rm -rf $export_dir
    }
  } catch {|err|
    log error $"($app) backup failed with message: ($err.msg)"
    send_fail $ping_url
    error make $err
    exit 1
  }

  log debug $"Backup of ($app) was successful."
  exit 0
}
