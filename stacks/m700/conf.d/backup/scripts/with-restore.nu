use std/log

use with-lockfile.nu *
use restic.nu *

export def main [
  app: string
  op: closure
] {
  let working_dir = '/tmp' | path join $app restore

  restic-restore

  do $op
}
