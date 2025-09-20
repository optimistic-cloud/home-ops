use std/log

use ./lib/with-lockfile.nu *
use ./lib/with-healthcheck.nu *
use ./lib/with-docker.nu *
use ./lib.nu *

def main [] { }

def "main init" [--provider-env-file: path] {
  restic init --provider-env-file $provider_env_file
}

def "main stats" [--provider-env-file: path] {
  restic stats --provider-env-file $provider_env_file
}

def "main ls" [--provider-env-file: path] {
  restic ls --provider-env-file $provider_env_file
}

def "main snapshots" [--provider-env-file: path] {
  restic snapshots --provider-env-file $provider_env_file
}

def "main forget" [--provider-env-file: path] {
  restic forget --provider-env-file $provider_env_file
}

def "main prune" [--provider-env-file: path] {
  restic prune --provider-env-file $provider_env_file
}

def "main restore" [--provider-env-file: path, --restore-path: path] {
  restic restore --provider-env-file $provider_env_file --target $restore_path
}
