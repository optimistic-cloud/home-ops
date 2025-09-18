use ./with-lockfile.nu *
use ./with-healthcheck.nu *
use ./with-docker.nu *

export def main [--provider-env-file: string, operation: closure]: string -> nothing {
    let app = $in
    with-lockfile $app {
        with-healthcheck $"($app)-backup" {
            with-backup-docker-volume {
                do $operation | backup --provider-env-file $provider_env_file
            }
        }
    }
}
