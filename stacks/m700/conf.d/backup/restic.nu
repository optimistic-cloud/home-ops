use std/log

use ./lib/with-lockfile.nu *
use ./lib/with-healthcheck.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

def main [] { }

def "main init" [--provider-env-file: path] { 
  $provider_env_file | with-restic --docker-args [] --restic-args ["init"]
}

def "main stats" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "stats"]
}

def "main ls" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "ls", "latest"]
}

def "main snapshots" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "snapshots", "--latest", "5"]
}

def "main forget" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "forget", "--prune", "--keep-within", "180d"]
}

def "main prune" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "prune"]
}

def "main restore" [--provider-env-file: path, --restore-path: path] {
    if ($restore_path | path exists) {
        error make {msg: "Restore path already exists" }
    }

    restic-restore --provider-env-file $provider_env_file --target $restore_path
}
