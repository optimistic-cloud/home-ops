export def main [app: string, operation: closure] {
    try {
        docker container stop $app
        do $operation
        docker container start $app
    } catch {|err|
        docker container start $app
        error make $err
    }
}