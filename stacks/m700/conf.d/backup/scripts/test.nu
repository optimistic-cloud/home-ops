use std/log

def main [--config (-c): path] {
    log debug "Backup process started"

    let config = open $config

    for app in ($config.apps) {
        print $"Backing up app: ($app)"
    }
}