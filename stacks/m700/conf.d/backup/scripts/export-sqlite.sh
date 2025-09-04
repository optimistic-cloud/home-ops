export_sqlite() {
    # 1 param: source database
    # 2 param: export database destination

    local src_db=$1
    local dest_db=$2

    if [ ! -f "${src_db}" ]; then
        echo "Error: Database file ${src_db} does not exist."
        exit 1
    fi

    sqlite3 ${src_db} ".backup '${dest_db}'"

    if [ ! -f "${dest_db}" ]; then
        echo "Error: Export database file ${dest_db} does not exist."
        exit 1
    fi

    if [ ! -s "${dest_db}" ]; then
        echo "Error: Export database file ${dest_db} is empty."
        exit 1
    fi

    integrity=$(sqlite3 "${dest_db}" "PRAGMA integrity_check;")
    if [ "$integrity" != "ok" ]; then
        echo "Error: Export database file ${dest_db} is corrupt."
        exit 1
    fi
}