use std/log

def with-lockfile [app:string, operation: closure] {
    let lockfile = $"/tmp/($app)-backup.lock"

    def aquire-lock [] {
        exec 200>($lockfile)
        flock -n 200
    }

    def release-lock [] {
        flock -u 200
        rm -f /tmp/($app)-backup.lock
    }

    try {
        aquire-lock
        do $operation
        release-lock
    } catch {|err|
        release-lock
        let message = $"Failed to open lockfile ($lockfile): ($err)"
        log error $message
        error make {msg: $message}
    }
}


let restic_cmd = "restic --verbose=0 --quiet"
#let git_commit = $(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

def main [--config (-c): path, --appp (-a): string] {
    with-lockfile $appp{
        print $"Starting backup for app: ($appp)"
    }


    let config = open $config

    $config.backup | where app == $appp | each { |b|
        with-env {
            AWS_ACCESS_KEY_ID: $b.AWS_ACCESS_KEY_ID
            AWS_SECRET_ACCESS_KEY: $b.AWS_SECRET_ACCESS_KEY
            RESTIC_REPOSITORY: $b.RESTIC_REPOSITORY
            RESTIC_PASSWORD: $b.RESTIC_PASSWORD
        } {
            do {
                (
                    ($restic_cmd) backup ...($files)
                        --files-from $app.include
                        --exclude-file $app.exclude
                        --exclude-caches
                        --one-file-system   
                        --tag git_commit=($git_commit)
                )

                ${restic_cmd} snapshots latest
                ${restic_cmd} ls latest --long --recursive
            } | str collect | log info $"Backup log:\n\n$it\n"

         }
    }
}

