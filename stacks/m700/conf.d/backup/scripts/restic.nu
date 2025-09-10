def process_exit_code [out: record, hc_slug: string, run_id: string]: record -> nothing {
    let exit_code = $in.exit_code
    let stdout = $in.stdout
    let stderr = $in.stderr

    $exit_code | exit-status-to-hc $hc_slug $run_id
    if $exit_code != 0 {
        $stderr | logs-to-hc $hc_slug $run_id
        error make { msg: $stderr }
    } else {
        $stdout | logs-to-hc $hc_slug $run_id
    }
}

export def create_restic_check_cmd [hc_slug: string, run_id: string]: nothing -> closure {
    {|subset: string|
        let out = ^restic check --read-data-subset $subset | complete
        $out | process_exit_code $hc_slug $run_id
    }
}

def to-prefix-string [prefix: string]: list<string> -> string { $in | each { |it| $"($prefix)=($it)" } | str join " " }

def assert_snapshot [threshold: duration = 1min] {
    let snapshot_time = (restic snapshots $in.0 --json | from json | get 0.time | into datetime)

    if not ((date now) < ($snapshot_time + $threshold)) {
        error make {msg: $"Snapshot is older than 1 minute. Snapshot time: ($snapshot_time), Current time: (date now)"}
    }
}

export def create_restic_backup_cmd [hc_slug: string, run_id: string]: nothing -> closure {
    {|includes: list<path>, excludes: list<string>, tags: list<string>|
        let exclude_as_string = $excludes | to-prefix-string "--exclude"
        let tags_as_string = $tags | to-prefix-string "--tag"

        let out = ^restic backup ...($includes) $exclude_as_string --skip-if-unchanged --exclude-caches --one-file-system $tags_as_string | complete
        $out | process_exit_code $hc_slug $run_id

        let snapshot_id = $out.stdout | lines | last | parse "{_} {snapshot} {_}" | get snapshot
        $snapshot_id | assert_snapshot 5min
    }
}
