use std/log

def main [--config (-c): path] {
    let config = open $config


    $config.backup | each { |b|
        let app = $config.apps | where app == $b.app | first
        let provider = $config.providers | where name == $b.provider | first

        with-env {
            AWS_ACCESS_KEY_ID: $"($provider.AWS_ACCESS_KEY_ID)"
            AWS_SECRET_ACCESS_KEY: $"($provider.AWS_SECRET_ACCESS_KEY)"
            RESTIC_REPOSITORY: $"($b.restic.repository)"
            RESTIC_PASSWORD_FILE: $"($b.restic.password-file)"
        } {
                print $"Backing up ($app) to ($provider)"
                print $env.AWS_ACCESS_KEY_ID
                print $env.AWS_SECRET_ACCESS_KEY
                print $env.RESTIC_REPOSITORY
                print $env.RESTIC_PASSWORD_FILE
        }


    }

#    $config.apps | each { |app|
#        $config.providers | par-each { |p|
#            with-env {
#                RESTIC_PASSWORD: $"s3:($p.api)/($p.path)/($app)/restic"
#                RESTIC_PASSWORD_FILE: "Z"
#            } {
#                print $"Backing up ($a) to ($p)"
#                print $env.RESTIC_REPOSITORY
#                print $env.RESTIC_PASSWORD_FILE
#            }
#        }
#    }
}

