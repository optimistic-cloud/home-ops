use std/log

use ./lib/with-lockfile.nu *
use ./lib/with-healthcheck.nu *
use ./lib/with-docker.nu *
use ./lib/utils.nu *

def "main init" [--provider-env-file: path] { 
    $provider_env_file | with-restic ["init"]
}

def "main stats" [--provider-env-file: path] { 
    $provider_env_file | with-restic ["stats"] 
}

def "main ls" [--provider-env-file: path] { 
    $provider_env_file | with-restic ["ls", "latest"] 
}

def "main snapshots" [--provider-env-file: path] { 
    $provider_env_file | with-restic ["snapshots", "--latest", "5"] 
}

def "main restore" [--provider-env-file: path, --restore-path: path] {
    if ($restore_path | path exists) {
        error make {msg: "Restore path already exists" }
    }

    restic-restore --provider-env-file $provider_env_file --target $restore_path
}