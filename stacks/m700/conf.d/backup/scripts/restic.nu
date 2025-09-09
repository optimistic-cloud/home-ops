export def assert_snapshot [threshold: duration = 1min] {
    let snapshot_time = (restic snapshots $in.0 --json | from json | get 0.time | into datetime)    

    if not ((date now) < ($snapshot_time + $threshold)) {
        error make {msg: $"Snapshot is older than 1 minute. Snapshot time: ($snapshot_time), Current time: (date now)"}
    }
}

def to-prefix-string [prefix: string]: string -> string { $in | each { |it| $"($prefix)=($it)" } | str join " " }

export def create_restic_backup_cmd [ hc_slug: string, run_id: string ]: nothing -> closure {
    {|includes: list<path>, excludes: list<string>, tags: list<string>|
        let exclude_as_string = $excludes | to-prefix-string "--exclude"
        let tags_as_string = $tags | to-prefix-string "--tag"

        let out = ^restic backup ...($includes) $exclude_as_string --exclude-caches --one-file-system $tags_as_string | complete

        $out.exit_code | exit-status-to-hc $hc_slug $run_id
        if $out.exit_code != 0 {
            $out.stderr | logs-to-hc $hc_slug $run_id
        } else {
            $out.stdout | logs-to-hc $hc_slug $run_id
        }

        let snapshot_id = $out.stdout | lines | last | parse "{_} {snapshot} {_}" | get snapshot
        $snapshot_id | assert_snapshot 1min
    }
}