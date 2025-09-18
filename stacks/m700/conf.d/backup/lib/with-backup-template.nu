export def main [app: string, operation: closure] {
    with-lockfile $app {
        with-healthcheck $"($app)-backup" {
            with-backup-docker-volume {
                do $operation
            }
        }
    }
}
