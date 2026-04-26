import sqlite3
import docker
import sys
from pathlib import Path
import typer

app = typer.Typer()

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


def backup_sqlite_from_volume(
    volume_name: str,
    db_name: str,
    dst_path: str | Path,
) -> None:
    dst_path = Path(dst_path)
    dst_path.parent.mkdir(parents=True, exist_ok=True)

    client = docker.from_env()

    # Spin up a minimal throw-away container with the volume mounted
    container = client.containers.create(
        image="alpine:latest",
        volumes={volume_name: {"bind": "/data", "mode": "ro"}},
    )

    try:
        # Stream the db file out as a tar archive
        stream, stat = container.get_archive(f"/data/{db_name}")
        print(f"Extracting '{db_name}' from volume '{volume_name}' ({stat['size']} bytes)")

        # Untar into a temp file so sqlite3 can read it
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_db = Path(tmp_dir) / db_name

            tar_bytes = b"".join(stream)
            with tarfile.open(fileobj=io.BytesIO(tar_bytes)) as tar:
                tar.extract(db_name, path=tmp_dir, filter="data")

            # Backup using sqlite3's native online backup API
            with sqlite3.connect(tmp_db) as src, sqlite3.connect(dst_path) as dst:
                src.backup(dst)

        print(f"Backup complete: volume:{db_name} → {dst_path}")

    finally:
        # Always remove the throw-away container
        container.remove()

    # Integrity check + table listing on the backup copy
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


@app.command()
def main(
    container_name: str  = typer.Option(..., help="Docker container name"),
    volume_name:    str  = typer.Option(..., help="Docker volume name"),
    export_dir: Path = typer.Option(..., help="Directory to write exports to"),
    db_name:   str  = typer.Option(..., help="SQLite database filename inside the volume"),
) -> None:

    export_container_env(container_name, export_dir)
    backup_sqlite_from_volume(
        volume_name=volume_name,
        db_name=db_name,
        dst_path=Path(export_dir) / db_name,
    )

    print("Hello from prepare_backup_data.py!")
    print(f"Container: {container_name}, Volume: {volume_name}, Export Dir: {export_dir}, DB Name: {db_name}")

if __name__ == "__main__":
    app()