use std/log

def "db export" [exported: path]: string -> path {
    let db = $in
    if not ($db | path exists) {
        error make {msg: $"Database file ($db) does not exist."}
    }
    if ($exported | path exists) {
        error make {msg: $"Location directory ($exported) does exist."}
    }
    sqlite3 $db $".backup '($exported)'"

    let integrity = (sqlite3 $"($exported)" "PRAGMA integrity_check;")
    if $integrity != "ok" {
        error make {msg: $"Export database file ($exported) is corrupt."}
    }
    $exported
}

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

# TODO: refactor func and with-logs toghether
def with-healthcheck [hc_slug: string, run_id: string, operation: closure] {
  let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)"
  let timeout = 10sec

  try {
    http get $"($url)/start?create=1&rid=($run_id)" --max-time $timeout | ignore
    do $operation
    http get $"($url)?rid=($run_id)" --max-time $timeout | ignore
  } catch {|err|
    http get $"($url)/fail&rid=($run_id)" --max-time $timeout | ignore
    error make $err
  }
}

def with-logs [hc_slug: string, run_id: string, operation: closure] {
    let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($hc_slug)?rid=($run_id)"
    let timeout = 10sec

    do $operation | collect | http post $"($url)" --max-time $timeout | ignore
}

def test_latest_snapshot [offset: duration = 1min] {
    let snapshot_time = (restic snapshots latest --json | from json | get 0.time | into datetime)    

    if not ((date now) < ($snapshot_time + $offset)) {
        error make {msg: $"Snapshot is older than 1 minute. Snapshot time: ($snapshot_time), Current time: (date now)"}
    }
}

def prepare-data [app: string, source_dir: path, export_dir: path] {
    match $app {
        "vaultwarden" => { 
            docker container stop $app
            $"($source_dir)/appdata/db.sqlite3" | db export $"($export_dir)/db.sqlite3" | ignore 
            docker container start $app
        }
        _   => { echo "default case" }
    }
}

def main [--config (-c): path, --app (-a): string] {
    let config = open $config

    if ($config.backup | where app == $app | is-empty) {
        error make {msg: $"App ($app) not found in config."}
    }

    with-lockfile $app {
        let git_commit = git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1

        let backup_dir = $"/opt/($app)"
        let export_dir = $"/tmp/($app)/export"

        mkdir $export_dir

        prepare-data $app $backup_dir $export_dir

        $config.backup | where app == $app | each { |b|
            with-env {
                AWS_ACCESS_KEY_ID: $b.AWS_ACCESS_KEY_ID
                AWS_SECRET_ACCESS_KEY: $b.AWS_SECRET_ACCESS_KEY
                RESTIC_REPOSITORY: $b.RESTIC_REPOSITORY
                RESTIC_PASSWORD: $b.RESTIC_PASSWORD
            } {
                let run_id = (random uuid -v 4)
                with-healthcheck $b.hc_slug $run_id {

                    with-logs $b.hc_slug $run_id {
                        let include = $b.include
                        let exclude = $b.exclude | each { |it| $"--exclude=($it)" } | str join " "
                        restic backup ...($include) $exclude --exclude-caches --one-file-system --tag git_commit=($git_commit) 
                    }
                    restic --verbose=0 --quiet check --read-data-subset 33%
                    test_latest_snapshot

                    # with-logs $b.hc_slug $run_id {
                    #     restic snapshots latest
                    # }
                    # with-logs $b.hc_slug $run_id {
                    #     restic ls latest --long --recursive
                    # }
                }
            }
        }
    }
}
