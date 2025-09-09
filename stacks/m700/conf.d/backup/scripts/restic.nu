export def assert_snapshot [threshold: duration = 1min] {
    let snapshot_time = (restic snapshots $in.0 --json | from json | get 0.time | into datetime)    

    if not ((date now) < ($snapshot_time + $threshold)) {
        error make {msg: $"Snapshot is older than 1 minute. Snapshot time: ($snapshot_time), Current time: (date now)"}
    }
}

let restic-backup = {|i,e|
    let git_commit = git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1
    let exclude_as_string = $e | each { |it| $"--exclude=($it)" } | str join " "
    let out = ^restic backup ...($i) $exclude_as_string --exclude-caches --one-file-system --tag git_commit=($git_commit) | complete

    $out.exit_code | exit-status-to-hc $hc_slug $run_id
    if $out.exit_code != 0 {
        $out.stderr | logs-to-hc $hc_slug $run_id
    } else {
        $out.stdout | logs-to-hc $hc_slug $run_id
    }

    let snapshot_id = $out.stdout | lines | last | parse "{_} {snapshot} {_}" | get snapshot
    $snapshot_id | assert_snapshot 1min
}
export restic-backup