use std/log

use with-backup.nu *
use with-restore.nu *

use with-docker.nu *
use sqlite-export.nu *
use restic.nu *

const app = "traefik"

def main [] {
  let data_dir = '/opt' | path join $app
  let working_dir = '/tmp' | path join $app export

  with-backup $app $working_dir { }
}

def "main restore" [] {
  with-restore $app
}
