export def main [app: string, operation: closure] {
    try {
        docker container stop $app | ignore
        do $operation
        docker container start $app | ignore
    } catch {|err|
        docker container start $app | ignore
        error make $err
    }
}