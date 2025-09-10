def do_logging_for [command: string]: record -> nothing {
  let exit_code = $in.exit_code
  let stdout = $in.stdout
  let stderr = $in.stderr

  if $exit_code != 0 {
    log error $"($command) failed with exit code ($exit_code) and message: \n($stderr)"
  } else {
    log debug $"($command) done successfully with message: \n($stdout)"
  }
}

def to-prefix-string [prefix: string]: list<string> -> string { $in | each { |it| $"($prefix)=($it)" } | str join " " }

#def assert_snapshot [threshold: duration = 1min]: string -> record {
#    let snapshot_id = $in.0
#
#    let snapshot_time = (restic snapshots $in.0 --json | from json | get 0.time | into datetime)
#
#    mut exit_code = 0
#    if not ((date now) < ($snapshot_time + $threshold)) {
#        $exit_code = 1
#    }
#    
#    {
#      stdout: "Snapshot is ok"
#      stderr: $"Snapshot is older than ($threshold) minutes. Snapshot time: ($snapshot_time), Current time: (date now)"
#      exit_code: $exit_code
#    }
#}

export def restic-check [subset: string] {
  log debug $"Start restic check command with subset of ($subset)"

  let out = ^restic check --read-data-subset $subset | complete
  $out | do_logging_for "Check"
  $out
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
  $out | do_logging_for "Backup"
  $out
}
