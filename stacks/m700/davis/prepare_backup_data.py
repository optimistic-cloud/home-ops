import sqlite3
import docker
import sys
from pathlib import Path


def export_container_env(container_name: str, export_dir: str | Path) -> Path:
    export_dir = Path(export_dir)
    export_dir.mkdir(parents=True, exist_ok=True)

    client = docker.from_env()
    container = client.containers.get(container_name)
    env_vars: list[str] = container.attrs["Config"]["Env"]

    env_file = export_dir / f"{container_name}.env"
    env_file.write_text("\n".join(env_vars) + "\n")

    print(f"Exported {len(env_vars)} env vars → {env_file}")
    return env_file


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


app = typer.Typer()

@app.command()
def main(
    container: str  = typer.Option(..., help="Docker container name"),
    volume:    str  = typer.Option(..., help="Docker volume name"),
    export_dir: Path = typer.Option(..., help="Directory to write exports to"),
    db_name:   str  = typer.Option(..., help="SQLite database filename inside the volume"),
) -> None:
    print("Hello from prepare_backup_data.py!")
    print(f"Container: {container}, Volume: {volume}, Export Dir: {export_dir}, DB Name: {db_name}")

if __name__ == "__main__":
    app()