use std/log

use with-backup.nu *
use with-docker.nu *
use sqlite-export.nu *

const app = "vaultwarden"

def main [] {
  let data_dir = '/opt' | path join $app
  let working_dir = '/tmp' | path join $app export

  with-backup $app $export_dir {
    with-docker $app {
        $"($data_dir)/appdata/db.sqlite3" | sqlite export $"($working_dir)/db.sqlite3" | ignore 
    }
  }
}

def "main restore" [] {
  print $"Restoring ($app)"

  exit 1
}
