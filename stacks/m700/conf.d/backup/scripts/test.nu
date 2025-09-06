use std/log

let restic_cmd = "restic --verbose=0 --quiet"
#let git_commit = $(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

def main [--config (-c): path, --appp (-a): string] {
    let config = open $config

    $config.backup | where app == $appp | each { |b|
        with-env {
            AWS_ACCESS_KEY_ID: $b.AWS_ACCESS_KEY_ID
            AWS_SECRET_ACCESS_KEY: $b.AWS_SECRET_ACCESS_KEY
            RESTIC_REPOSITORY: $b.RESTIC_REPOSITORY
            RESTIC_PASSWORD: $b.RESTIC_PASSWORD
        } {
            print $"Backing up app: ($appp)"
            print $env.RESTIC_REPOSITORY
            print $env.RESTIC_PASSWORD
            print $env.AWS_ACCESS_KEY_ID
            print $env.AWS_SECRET_ACCESS_KEY

         }
    }
    #     with-env {
    #         AWS_ACCESS_KEY_ID: $"($provider.AWS_ACCESS_KEY_ID)"
    #         AWS_SECRET_ACCESS_KEY: $"($provider.AWS_SECRET_ACCESS_KEY)"
    #         RESTIC_REPOSITORY: $"($b.restic.repository)"
    #         RESTIC_PASSWORD_FILE: $"($b.restic.password-file)"
    #     } {
    #         if not ($env.RESTIC_PASSWORD_FILE | path exists) {
    #             error make { msg: $"($env.RESTIC_PASSWORD_FILE) not found" }
    #         }

    #         do {
    #             (
    #                 ($restic_cmd) backup
    #                     --files-from $app.include
    #                     --exclude-file $app.exclude
    #                     --exclude-caches
    #                     --one-file-system
    #                     --tag git_commit=($git_commit)
    #             )

    #             ${restic_cmd} snapshots latest
    #             ${restic_cmd} ls latest --long --recursive
    #         } | str collect | log info $"Backup log:\n\n$it\n"
    #     }

    # }

    # $config.backup | each { |b|
    #     let app = $config.apps | where name == $b.app | first
    #     let provider = $config.providers | where name == $b.provider | first

    #     with-env {
    #         AWS_ACCESS_KEY_ID: $"($provider.AWS_ACCESS_KEY_ID)"
    #         AWS_SECRET_ACCESS_KEY: $"($provider.AWS_SECRET_ACCESS_KEY)"
    #         RESTIC_REPOSITORY: $"($b.restic.repository)"
    #         RESTIC_PASSWORD_FILE: $"($b.restic.password-file)"
    #     } {
    #         if not ($env.RESTIC_PASSWORD_FILE | path exists) {
    #             error make { msg: $"($env.RESTIC_PASSWORD_FILE) not found" }
    #         }

    #         do {
    #             (
    #                 ($restic_cmd) backup
    #                     --files-from $app.include
    #                     --exclude-file $app.exclude
    #                     --exclude-caches
    #                     --one-file-system
    #                     --tag git_commit=($git_commit)
    #             )

    #             ${restic_cmd} snapshots latest
    #             ${restic_cmd} ls latest --long --recursive
    #         } | str collect | ^$curl_cmd --data-binary @- $ping_url
    #     }

    # }
}

