use std/log

use with-lockfile.nu *
use restic.nu *

export def main [app: string] {
  let working_dir = '/tmp' | path join $app restore

  try {
    # Prepare working directory
    rm -rf $working_dir
    mkdir $working_dir
  
    restic-restore
  } catch {|err|
    log error $"Error: ($err)"
    exit 1
  }
}
