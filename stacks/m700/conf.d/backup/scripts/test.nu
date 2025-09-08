use std/log

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
#    | http post $"($url)" --max-time $timeout | ignore
#        do { $operation }| collect { |x| print $"HELLOOOOO=======($x)" }
    #| http post $"($url)" --max-time $timeout | ignore
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

def test_snapshot [offset: duration = 1min] {
    let snapshot_time = (restic snapshots latest --json | from json | get 0.time | into datetime)    

    if not ((date now) < ($snapshot_time + $offset)) {
        error make {msg: $"Snapshot is older than 1 minute. Snapshot time: ($snapshot_time), Current time: (date now)"}
    }
}

def main [--config (-c): path, --app (-a): string] {
    let config = open $config

    if ($config.backup | where app == $app | is-empty) {
        error make {msg: $"App ($app) not found in config."}
    }

    with-lockfile $app {
        print $"Starting backup for app: ($app)"
        
        let git_commit = git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1

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
                    with-logs $b.hc_slug $run_id {
                        restic snapshots latest
                    }
                    with-logs $b.hc_slug $run_id {
                        restic ls latest --long --recursive
                    }
                    test_snapshot
                    #do $restic_block $include $exclude $git_commit
                }
            }
        }
    }


    # let config = open $config

    # $config.backup | where app == $appp | each { |b|
    #     with-env {
    #         AWS_ACCESS_KEY_ID: $b.AWS_ACCESS_KEY_ID
    #         AWS_SECRET_ACCESS_KEY: $b.AWS_SECRET_ACCESS_KEY
    #         RESTIC_REPOSITORY: $b.RESTIC_REPOSITORY
    #         RESTIC_PASSWORD: $b.RESTIC_PASSWORD
    #     } {
    #         do {
    #             (
    #                 ($restic_cmd) backup ...($files)
    #                     --files-from $app.include
    #                     --exclude-file $app.exclude
    #                     --exclude-caches
    #                     --one-file-system   
    #                     --tag git_commit=($git_commit)
    #             )

    #             ${restic_cmd} snapshots latest
    #             ${restic_cmd} ls latest --long --recursive
    #         } | str collect | log info $"Backup log:\n\n$it\n"

    #      }
    # }
}

