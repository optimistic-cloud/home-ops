use std/log

def main [--target: string] {
  log debug $"Starting backup process for target: ($target)"

  with-env {
    GIT_SHA: (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1),
    RESTIC_ENV_FILE: $"($target).restic.env"
  } { 
    ^docker compose -f docker-compose.backup.yaml run --rm backup
    ^docker compose -f docker-compose.backup.yaml run --rm forget
    ^docker compose -f docker-compose.backup.yaml run --rm check
  }

  log debug $"Backup process completed for target: ($target)"
  exit 0
}