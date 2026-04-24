import sqlite3
import sys
from pathlib import Path


def backup_sqlite(src_path: str | Path, dst_path: str | Path) -> None:
    """
    Backup a SQLite database, verify its integrity, and print its tables.

    Args:
        src_path: Path to the source database (inside the container mount).
        dst_path: Path to the destination backup database.

    Raises:
        SystemExit: If the integrity check fails.
    """
    src_path = Path(src_path)
    dst_path = Path(dst_path)

    # Ensure destination directory exists
    dst_path.parent.mkdir(parents=True, exist_ok=True)

    # Backup
    with sqlite3.connect(src_path) as src, sqlite3.connect(dst_path) as dst:
        src.backup(dst)

    print(f"Backup complete: {src_path} → {dst_path}")

    # Integrity check + table listing on the backup
    with sqlite3.connect(dst_path) as con:
        result = con.execute("PRAGMA integrity_check;").fetchone()[0]
        if result == "ok":
            print("Database integrity: OK")
        else:
            print(f"Database integrity: FAILED ({result})", file=sys.stderr)
            sys.exit(1)

        tables = [row[0] for row in con.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
        ).fetchall()]
        print(f"Tables: {tables}")
