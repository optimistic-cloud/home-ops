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
  log debug $"Start restic backup command with 
    includes: ($includes) 
    excludes: ($excludes)
    tags: ($tags)
  "

  let exclude_as_string = $excludes | to-prefix-string "--exclude"
  let tags_as_string = $tags | to-prefix-string "--tag"

  let out = ^restic backup ...($includes) $exclude_as_string --skip-if-unchanged --exclude-caches --one-file-system $tags_as_string | complete

  if $out.exit_code != 0 {
    log error $"Backup failed with exit code ($out.exit_code) and message:
      ($out.stderr)
    "
  } else {
    log debug $"Backup done successfully with message:
      ($out.stdout)
    "
  }

  $out
}
