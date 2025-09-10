use std/log

use with-backup.nu *
use with-docker.nu *
use sqlite-export.nu *

def main [] {
  const app = "vaultwarden"

  let data_dir = '/opt' | path join $app
  let export_dir = '/tmp' | path join $app export

  with-backup $app $export_dir {
    with-docker $app {
        $"($data_dir)/appdata/db.sqlite3" | sqlite export $"($export_dir)/db.sqlite3" | ignore 
    }
  }
}
