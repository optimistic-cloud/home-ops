use utils.nu *

export def abc [dest_db: path]: path -> nothing {
    print "Starting SQLite database export from Docker volume..."
    let src_db = $in

    try {
        ^docker volume create vaultwarden-data-export
        ^docker run --rm -v vaultwarden-data:/data:ro -v vaultwarden-data-export:/export:rw alpine/sqlite /data/db.sqlite3 ".backup '/export/db.sqlite3'"
        ^docker run --rm -v vaultwarden-data-export:/export:ro alpine ls -la /export; pwd
        ^docker run --rm -v vaultwarden-data-export:/export:ro alpine touch /export/fake.sqlite3.txt
        ^docker run --rm -v vaultwarden-data-export:/export:rw alpine/sqlite '/export/fake.sqlite3' "PRAGMA integrity_check;"
        ^docker volume rm vaultwarden-data-export
    } catch {|err|
        ^docker volume rm vaultwarden-data-export
        log error $"Error: ($err)"
        error make $err
    }


    #try {
        #^docker volume create vaultwarden-data-export
        #^docker volume ls | print
        #(
        #    ^docker run --rm
        #        -v vaultwarden-data:/data:ro
        #        -v vaultwarden-data-export:/export:rw
        #        alpine/sqlite $src_db ".backup '($dest_db)'"
        #)

        #let out1 = ^docker run --rm -v vaultwarden-data-export:/export:ro alpine id | complete
        #let out2 = ^docker run --rm -v vaultwarden-data-export:/export:ro alpine ls -la / | complete
        #let out3 = ^docker run --rm -v vaultwarden-data-export:/export:ro alpine ls -la /export | complete
        #let integrity_check = ^docker run --rm -v vaultwarden-data-export:/export:ro alpine/sqlite $"($dest_db)" "PRAGMA integrity_check;" | complete




        #let integrity = (sqlite3 $"($dest_db)" "PRAGMA integrity_check;")
        #if $out1 != "ok" {
        #    error make {msg: $"Export database file ($dest_db) is corrupt."}
        #}
        
        #$out1 | do_logging_for "SQLite database export"
        
        
        #docker volume rm vaultwarden-data-export
    #} catch {|err|
    #    docker volume rm vaultwarden-data-export
    #    log error $"Error: ($err)"
    #    error make $err
    #}
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
