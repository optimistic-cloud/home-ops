use std/log

def main [--config (-c): path] {
    log debug "Backup process started"

    let config = open $config

    $config.apps | each { |a|
        $config.providers | par-each { |p|
            echo $"Backing up ($a) to ($p)"
        }
    }
}

