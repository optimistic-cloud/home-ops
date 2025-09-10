use std/log

use with-backup.nu *
use with-docker.nu *
use sqlite-export.nu *

const app = "vaultwarden"

def main [] {
  let source_dir = '/opt' | path join $app
  let export_dir = '/tmp' | path join $app export

  with-backup $app {
    with-docker $app {
        $"($source_dir)/appdata/db.sqlite3" | sqlite export $"($export_dir)/db.sqlite3" | ignore 
    }
  }
}
