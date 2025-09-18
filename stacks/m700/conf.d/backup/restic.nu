use std/log

use ./lib/with-lockfile.nu *
use ./lib/with-healthcheck.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

def main [] { }

def "main init" [--provider-env-file: path] { 
  with-restic --docker-args ["--env-file", $provider_env_file] --restic-args ["init"]
}

def "main stats" [--provider-env-file: path] { 
    with-restic --docker-args ["--env-file", $provider_env_file] --restic-args ["stats"]
}

def "main ls" [--provider-env-file: path] { 
    with-restic --docker-args ["--env-file", $provider_env_file] --restic-args ["ls", "latest"]
}

def "main snapshots" [--provider-env-file: path] { 
    with-restic --docker-args ["--env-file", $provider_env_file] --restic-args ["snapshots", "--latest", "5"]
}

def "main restore" [--provider-env-file: path, --restore-path: path] {
    if ($restore_path | path exists) {
        error make {msg: "Restore path already exists" }
    }

    restic-restore --provider-env-file $provider_env_file --target $restore_path
}
