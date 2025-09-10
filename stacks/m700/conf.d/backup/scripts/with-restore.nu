use std/log

use with-lockfile.nu *
use restic.nu *

export def main [
  app: string
  op: closure
] {
  

do $op
}
