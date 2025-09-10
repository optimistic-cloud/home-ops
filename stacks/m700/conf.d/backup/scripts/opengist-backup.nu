use std/log

use with-backup.nu *
use with-docker.nu *
use sqlite-export.nu *

const app = "opengist"

def main [] {
  let data_dir = '/opt' | path join $app
  let working_dir = '/tmp' | path join $app export

  with-backup $app $working_dir {
    with-docker $app {
        $"($data_dir)/appdata/($app).db" | sqlite export $"($working_dir)/($app).db" | ignore
    }
  }
}

def "main restore" [] {
  print $"Restoring ($app)"

  exit 1
}
