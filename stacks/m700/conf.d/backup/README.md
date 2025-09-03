# Backup System Documentation

This directory contains scripts and configuration for automated backups of applications in the `stacks/m700` environment.

## How It Works

1. **Main Script:**  
   The main backup script (`backup.sh`) is generic and takes the application name as its first argument.  
   Example usage:
   ```sh
   ./backup.sh vaultwarden
   ```

1. **Exporting application data:**
   App-specific export logic is defined in `/opt/${app}/conf.d/backup/backup-export.sh`.  
   This script must provide an `export_data` function, which is called to export the app's data to a temporary directory.

## Adding a New Application

1. Create an app-specific `backup-export.sh` in `/opt/${app}/conf.d/backup/` that defines `export_data`.
2. Add include/exclude lists as needed.
3. Run the main backup script with the app name.
