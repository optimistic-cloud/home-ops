#
# This script is not ready and not testes!
# 
use std/log

let restic_cmd = "restic --verbose=0 --quiet"
let curl_cmd = "curl -fsS -m 10 --retry 5"

backup_dir="/opt/${app}"
export_dir="/tmp/${app}/export"

def require [] {
    if not ($in | path exists) {
        error make {msg: $"Required file ($in) does not exist."}
    }
}

def check_resources [app: string] {
    $"/opt/($app)/conf.d/backup-export.sh" | require
    $"/opt/($app)/conf.d/backup/include.txt" | require
    $"/opt/($app)/conf.d/backup/exclude.txt" | require
}

def __healthcheck-request [url: string, endpoint: string] {
  let full_url = if ($endpoint == "") { $url } else { $"($url)($endpoint)" }
  let full_url1 = $"($full_url)?create=1"
  let timeout = 10sec

  log debug $"Calling healthcheck endpoint: ($full_url1)"

  try {
    http get $full_url1 --max-time $timeout | ignore
  } catch {
    log warning $"Failed to call healthcheck endpoint: ($full_url1)"
  }
}

export def with-healthcheck [ping_key: string, app: string, operation: closure] {
  let url = $"https://hc-ping.com/($ping_key)/($app)-backup${1}?create=1"

  try {
    __healthcheck-request $url "/start"
    do $operation
    __healthcheck-request $url ""
  } catch {|err|
    log error $"Error during healthcheck operation: ($err)"

    __healthcheck-request $url "/fail"
    error make $err
  }
}

def main [app: string] {
    check_resources $app

    let backup_dir = $"/opt/($app)"
    let export_dir = $"/tmp/($app)/export"
    let git_commit = $(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)
    let restic_version = $(restic version | cut -d ' ' -f2)

    with-healthcheck $env.HC_PING_KEY {
        rm -rf $export_dir && mkdir -p -m 700 $export_dir

        source $"/opt/($app)/conf.d/backup/backup-export.nu"; export_data $backup_dir $export_dir $app
        
        (
            ($restic_cmd) backup
                /opt/.env
                --files-from $"/opt/($app)/conf.d/backup/include.txt"
                --exclude-file $"/opt/($app)/conf.d/backup/exclude.txt"
                --exclude-caches
                --one-file-system
                --tag app=($app)
                --tag git_commit=($git_commit)
                --tag restic_version=($restic_version)
        )

        ($restic_cmd) check --read-data-subset 100%
    }

    rm -rf $export_dir
}