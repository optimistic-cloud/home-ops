use std/log

use with-backup.nu *
use with-restore.nu *

use with-docker.nu *
use sqlite-export.nu *
use restic.nu *

const app = "pocket-id"

def main [] {
  let data_dir = '/opt' | path join $app
  let working_dir = '/tmp' | path join $app export

  with-backup $app $working_dir {
    with-docker $app {
        let src_db = $data_dir | path join appdata $"($app).db"
        let dest_db = $working_dir | path join $"($app).db"

        $src_db | sqlite export $dest_db | ignore
    }
  }
}

def "main restore" [] {
  with-restore $app
}
