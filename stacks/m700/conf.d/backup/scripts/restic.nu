def process_exit_code [hc_slug: string, run_id: string]: record -> nothing {
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

#export def create_restic_check_cmd [hc_slug: string, run_id: string]: nothing -> closure {
#    {|subset: string|
#        ^restic check --read-data-subset $subset | complete
#        #let out = ^restic check --read-data-subset $subset | complete
#        #$out | process_exit_code $hc_slug $run_id
#    }
#}

export def restic-check [subset: string] {
    ^restic check --read-data-subset $subset | complete
}

def to-prefix-string [prefix: string]: list<string> -> string { $in | each { |it| $"($prefix)=($it)" } | str join " " }

export def assert_snapshot [threshold: duration = 1min]: string -> record {
    let snapshot_id = $in.0

    let snapshot_time = (restic snapshots $in.0 --json | from json | get 0.time | into datetime)

    mut exit_code = 0
    if not ((date now) < ($snapshot_time + $threshold)) {
        $exit_code = 1
    }
    
    {
      stdout: "Snapshot is ok"
      stderr: $"Snapshot is older than ($threshold) minutes. Snapshot time: ($snapshot_time), Current time: (date now)"
      exit_code: $exit_code
    }
}

export def restic-backup [includes: list<path>, excludes: list<string>, tags: list<string>] {
    let exclude_as_string = $excludes | to-prefix-string "--exclude"
    let tags_as_string = $tags | to-prefix-string "--tag"

    ^restic backup ...($includes) $exclude_as_string --skip-if-unchanged --exclude-caches --one-file-system $tags_as_string | complete
}

#export def create_restic_backup_cmd [hc_slug: string, run_id: string]: nothing -> closure {
#    {|includes: list<path>, excludes: list<string>, tags: list<string>|
#        let exclude_as_string = $excludes | to-prefix-string "--exclude"
#        let tags_as_string = $tags | to-prefix-string "--tag"
#
#        ^restic backup ...($includes) $exclude_as_string --skip-if-unchanged --exclude-caches --one-file-system $tags_as_string | complete
#        #let out = ^restic backup ...($includes) $exclude_as_string --skip-if-unchanged --exclude-caches --one-file-system $tags_as_string | complete
#        #$out
#
#        #let snapshot_id = $out.stdout | lines | last | parse "{_} {snapshot} {_}" | get snapshot
#        #$snapshot_id | assert_snapshot 5min
#    }
#}
