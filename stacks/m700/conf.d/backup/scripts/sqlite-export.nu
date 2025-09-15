use utils.nu *

export def abc []: record -> nothing {
    ^docker run --rm -v ($in.src_volume):/data:ro -v ($in.dest_volume):/export:rw alpine/sqlite ($in.src_db) $".backup '($in.dest_db)'"
    ^docker run --rm -v ($in.dest_volume):/export:rw alpine/sqlite $'($in.dest_db)' "PRAGMA integrity_check;"
}

export def export-sqlite-db []: record -> nothing {
    let config = $in

    (
        ^docker run --rm 
            -v $"($config.src_volume):/data:ro"
            -v $"($config.dest_volume):/export:rw"
            alpine/sqlite $'($config.src_db)' $".backup '($config.dest_db)'"
    )
    (
        ^docker run --rm 
            -v $"($config.dest_volume):/export:rw"
            alpine/sqlite $'($config.dest_db)' "PRAGMA integrity_check;"
    )
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
