use std/log

use ./lib/with-backup-template-one.nu *
use ./lib/with-docker.nu *
use ./lib/lib.nu *

const app = "outline"
const container_name = "outline"
const pg_container_name = "outline-postgres"
const storage_docker_volume = "outline_storage-data"
const database_docker_volume = "outline_database-data"

def get-pg-setting [key: string, default: string]: string {
    let env_list = (^docker container inspect $pg_container_name | from json | get 0.Config.Env)
    let matches = $env_list | where {|e| $e | str starts-with $"($key)=" }

    if ($matches | is-empty) {
        $default
    } else {
        $matches.0 | str replace $"($key)=" ""
    }
}

def export-postgres-dump [backup_volume: string] {
    let tmp_dump = (mktemp)

    let pg_user = get-pg-setting "POSTGRES_USER" "user"
    let pg_db = get-pg-setting "POSTGRES_DB" "outline"
    let pg_pass = get-pg-setting "POSTGRES_PASSWORD" ""

    try {
        if ($pg_pass | is-empty) {
            ^docker exec $pg_container_name pg_dump -U $pg_user $pg_db | save --force --raw $tmp_dump
        } else {
            ^docker exec -e $"PGPASSWORD=($pg_pass)" $pg_container_name pg_dump -U $pg_user $pg_db | save --force --raw $tmp_dump
        }

        do {
            let da = [
                "-v", $"($backup_volume):/data:rw",
                "-v", $"($tmp_dump):/import/dump.sql:ro"
            ]
            let args = ["sh", "-c", "cp /import/dump.sql /data/postgres-dump.sql"]

            with-alpine --docker-args $da --args $args
        }
    } catch {|err|
        rm $tmp_dump | ignore
        error make $err
    }

    rm $tmp_dump | ignore
}

def main [provider_name: string, provider_env_file: path] {
    $app | with-backup-template-one $provider_name $provider_env_file {
        let backup_docker_volume = $in

        $backup_docker_volume | export-postgres-dump

        {
            container_name: $container_name
            volumes: {
                storage: $storage_docker_volume
                database: $database_docker_volume
                config: $backup_docker_volume
            }
        }
    }
}