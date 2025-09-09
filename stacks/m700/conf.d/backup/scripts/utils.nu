export def test_latest_snapshot [threshold: duration = 1min] {
    let snapshot_time = (restic snapshots latest --json | from json | get 0.time | into datetime)    

    if not ((date now) < ($snapshot_time + $threshold)) {
        error make {msg: $"Snapshot is older than 1 minute. Snapshot time: ($snapshot_time), Current time: (date now)"}
    }
}