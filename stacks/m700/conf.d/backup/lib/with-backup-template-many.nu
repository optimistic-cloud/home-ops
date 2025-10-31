use ./with-lockfile.nu *
use ./with-healthcheck.nu *
use ./with-docker.nu *
use ./lib.nu *

export def main [--provider-env-files: list<path>, operation: closure]: string -> nothing {
    let app = $in
    with-lockfile $app {
        with-healthcheck $"($app)-backup" {
            with-backup-docker-volume {
                do $operation | backup --provider-env-files $provider_env_files
            }
        }
    }
}
