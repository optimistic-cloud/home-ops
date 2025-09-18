export def main [operation: closure]: string -> nothing {
  let app = $in
  with-lockfile $app {
    with-healthcheck $"($app)-backup" {
      with-backup-docker-volume {
        do $operation
      }
    }
  }
}
