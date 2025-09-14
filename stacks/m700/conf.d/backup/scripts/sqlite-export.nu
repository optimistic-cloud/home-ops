use utils.nu *

export def "sqlite export2" [docker_volume: string, dest_db: path]: path -> nothing {
    let src_db = $in
    
    try {
        print "1"
        docker volume create vaultwarden-data-export
        print "2"
        let out = (
            ^docker run --rm
                -v vaultwarden-data:/data:ro
                -v vaultwarden-data-export:/export:rw
                alpine/sqlite $src_db ".backup '$dest_db'"
        ) | complete
        print "3"
        print $"test3 ($out)"
        $out | do_logging_for "SQLite database export"

        let integrity = (sqlite3 $"($dest_db)" "PRAGMA integrity_check;")
        if $integrity != "ok" {
            error make {msg: $"Export database file ($dest_db) is corrupt."}
        }
        docker volume rm vaultwarden-data-backup
    } catch {|err|
        docker volume rm vaultwarden-data-backup
        log error $"Error: ($err)"
        error make $err
    }
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
