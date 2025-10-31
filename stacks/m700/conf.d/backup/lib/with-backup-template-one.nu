use ./with-lockfile.nu *
use ./with-healthcheck.nu *
use ./with-docker.nu *
use ./lib.nu *

export def main [provider_name: string, --provider-env-file: path, operation: closure]: string -> nothing {
    let app = $in
    with-lockfile $app {
        with-healthcheck $"($app)@($provider_name)" {
            with-backup-docker-volume {
                do $operation | backup-one --provider-env-file $provider_env_file
            }
        }
    }
}
