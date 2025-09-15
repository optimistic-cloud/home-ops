use std/log

use with-backup.nu *
use with-restore.nu *

use with-docker.nu *
use sqlite-export.nu *
use restic.nu *

const app = "gitea"

def main [] {
  let data_dir = '/opt' | path join $app
  let working_dir = '/tmp' | path join $app export

  with-backup $app $working_dir {
    let dump_location = '/var/lib/gitea'
    let dump_name = 'gitea-dump.tar.gz'

    ^docker exec -u git gitea rm -f $"($dump_location)/($dump_name)" | ignore
    ^docker exec -u git gitea mkdir -p $dump_location | ignore
    (
      ^docker exec -u git gitea /usr/local/bin/gitea
        dump --work-path /tmp
          --file $dump_name
          --config /etc/gitea/app.ini
          --database sqlite3
          --type tar.gz
          | ignore
    )
    ^docker cp gitea:$"($dump_location)/($dump_name)" $working_dir | ignore
    ^docker exec -u git gitea rm -f $"($dump_location)/($dump_name)" | ignore
  }
}
 
def "main restore" [] {
  with-restore $app
}
