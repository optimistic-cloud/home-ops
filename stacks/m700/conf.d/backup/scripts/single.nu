# closure
# function
# pipeline

def test_latest_snapshot [offset: duration = 1min] {
    let snapshot_time = (restic snapshots latest --json | from json | get 0.time | into datetime)    

    if not ((date now) < ($snapshot_time + $offset)) {
        error make {msg: $"Snapshot is older than 1 minute. Snapshot time: ($snapshot_time), Current time: (date now)"}
    }
}

def with-healthcheck [hc_slug: string, run_id: string, operation: closure] {
  let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)"
  let timeout = 10sec

  try {
    http get $"($url)/start?create=1&rid=($run_id)" --max-time $timeout | ignore
    do $operation
    http get $"($url)?rid=($run_id)" --max-time $timeout | ignore
  } catch {|err|
    http get $"($url)/fail?rid=($run_id)" --max-time $timeout | ignore
    error make $err
  }
}

def with-logs [hc_slug: string, run_id: string, operation: closure] {
    let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)?rid=($run_id)"
    let timeout = 10sec

    do $operation | collect | http post $"($url)" --max-time $timeout | ignore
}

def logs-to-hc [hc_slug: string, run_id: string] {
    let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)?rid=($run_id)"
    let timeout = 10sec

    $in | collect | http post $"($url)" --max-time $timeout | ignore
}

def main [] {
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
    let git_commit = git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1

    let run_id = (random uuid -v 4)
    let hc_slug = "vaultwarden-backup"
    with-healthcheck $hc_slug $run_id {
        restic backup ...($include) $exclude --exclude-caches --one-file-system --tag git_commit=($git_commit) | logs-to-hc $hc_slug $run_id
        test_latest_snapshot
        restic --verbose=0 --quiet check --read-data-subset 33%
    }
}