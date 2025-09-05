use std/log

def main [--config (-c): path] {
    let config = open $config

    $config.apps | each { |a|
        $config.providers | par-each { |p|
            with-env {
                RESTIC_REPOSITORY: $"s3:($p)/($a)"
                RESTIC_PASSWORD_FILE: "Z"
            } {
                print $"Backing up ($a) to ($p)"
                print $env.RESTIC_REPOSITORY
                print $env.RESTIC_PASSWORD_FILE
            }
        }
    }
}

