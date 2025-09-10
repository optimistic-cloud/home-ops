use std/log

use with-backup.nu *

const app = "vaultwarden"

def main [] {
  with-backup $app {
    with-docker $app {
        $"($source_dir)/appdata/db.sqlite3" | sqlite export $"($export_dir)/db.sqlite3" | ignore 
    }
  }
}
