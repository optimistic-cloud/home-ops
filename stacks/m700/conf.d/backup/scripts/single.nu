# closure
# function
# pipeline

# Nushell does not support file locking natively.
def with-lockfile [app:string, operation: closure] {
    let lockfile = $"/tmp/($app)-backup.lock"

    # Acquire lock: create the lockfile with our PID
    def acquire-lock [] {
        if not ($lockfile | path exists) {
            $nu.pid | save $lockfile
        } else {
            let pid = (open $lockfile)
            error make {msg: $"Lockfile ($lockfile) exists. Held by PID ($pid). Another backup process might be running."}
        }
    }

    # Release lock only if it’s ours
    def release-lock [] {
        if ($lockfile | path exists) {
            let pid = (open $lockfile)
            if $pid == ($nu.pid | into string) {
                rm $lockfile
            } else {
                log warning $"Lockfile ($lockfile) is held by PID ($pid), not us. Skipping removal."
            }
        }
    }

    try {
        acquire-lock
        do $operation
        release-lock
    } catch {|err|
        release-lock
        error make $err
    }
}

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

            docker container stop $app
            $"($source_dir)/appdata/db.sqlite3" | db export $"($export_dir)/db.sqlite3" | ignore 
            docker container start $app

            restic backup ...($include) $exclude --exclude-caches --one-file-system --tag git_commit=($git_commit) | logs-to-hc $hc_slug $run_id
            test_latest_snapshot
            restic --verbose=0 --quiet check --read-data-subset 33%

            rm -rf $export_dir
        }
    }
}