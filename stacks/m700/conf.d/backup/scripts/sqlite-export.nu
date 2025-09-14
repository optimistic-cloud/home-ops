use utils.nu *

export def "sqlite export2" [docker_volume: string, dest_db: path]: path -> path {
    let src_db = $in

    let out = (
        ^docker run --rm
            --user "1000:1000"
            -v $docker_volume:/data:ro
            -v ($target):/export
            -e TZ=Europe/Berlin
            alpine/sqlite $src_db ".backup '$dest_db'"
    )
    $out | do_logging_for "SQLite database export"

    let integrity = (sqlite3 $"($dest_db)" "PRAGMA integrity_check;")
    if $integrity != "ok" {
        error make {msg: $"Export database file ($dest_db) is corrupt."}
    }
    $dest_db
}

export def "sqlite export" [target: path]: string -> path {
    let db = $in

    if not ($db | path exists) {
        error make {msg: $"Database file ($db) does not exist."}
    }
    if ($target | path exists) {
        error make {msg: $"Location directory ($target) does exist."}
    }

    let out = ^sqlite3 $db $".backup '($target)'" | complete
    $out | do_logging_for "SQLite database export"

    let integrity = (sqlite3 $"($target)" "PRAGMA integrity_check;")
    if $integrity != "ok" {
        error make {msg: $"Export database file ($target) is corrupt."}
    }
    $target
}
