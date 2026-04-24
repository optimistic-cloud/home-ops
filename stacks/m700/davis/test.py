import typer

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