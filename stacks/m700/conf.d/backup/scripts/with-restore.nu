use std/log

use with-lockfile.nu *
use restic.nu *

export def main [app: string] {
  let working_dir = '/tmp' | path join $app restore
  let snapshot_id = latest

  try {
    # Prepare working directory
    rm -rf $working_dir
    mkdir $working_dir
  
    restic-restore $snapshot_id $working_dir
  } catch {|err|
    log error $"Error: ($err)"
    exit 1
  }
}
