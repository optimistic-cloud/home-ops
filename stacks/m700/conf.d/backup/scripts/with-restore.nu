use std/log

use with-lockfile.nu *
use restic.nu *

export def main [
  app: string
  working_dir: path
  op: closure
] {
  do $op
}
