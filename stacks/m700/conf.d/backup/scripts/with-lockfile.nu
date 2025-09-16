
# Nushell does not support file locking natively.
export def main [operation: closure] {
    let lockfile = mktemp lock.XXX
    
    # Acquire lock: create the lockfile with our PID
    def acquire-lock [] {
        if not ($lockfile | path exists) {
            $nu.pid | save $lockfile
        } else {
            let pid = (open $lockfile)
            error make {msg: $"Lockfile ($lockfile) exists. Held by PID ($pid). Another backup process might be running."}
        }
    }

    # Release lock only if it’s ours
    def release-lock [] {
        if ($lockfile | path exists) {
            let pid = (open $lockfile)
            if $pid == ($nu.pid | into string) {
                rm $lockfile
            } else {
                log warning $"Lockfile ($lockfile) is held by PID ($pid), not us. Skipping removal."
            }
        }
    }

    try {
        acquire-lock
        do $operation
        release-lock
    } catch {|err|
        # https://github.com/nushell/nushell/issues/15279
        release-lock
        error make $err
    }
}
