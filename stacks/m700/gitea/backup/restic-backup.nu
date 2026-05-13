use std/log

const name = "gitea"
const docker_container_name = $name
const docker_volume_name = $"($name)-data"
const database_name = $"($name)-database.db"

def with-stopped-docker-container [name: string, operation: closure] {
  docker container stop $name
  try {
    do $operation
    docker container start $name
  } catch {|err|
      # https://github.com/nushell/nushell/issues/15279
      docker container start $name
      error make $err
  }
}

def with-tmp-dir [name: string, operation: closure] {
  let export_dir = (^mktemp -d $"/tmp/($name)-backup-XXXXXX" | str trim)

  try {
    do $operation $export_dir
    rm -rf $export_dir
  } catch {|err|
    # TODO: https://github.com/nushell/nushell/issues/15279
    rm -rf $export_dir
    error make $err
  }
}

def backup-to-target [target: string] {
  let compose_file = $"compose.($target).yaml"
  let restic_env_file = $"($target).restic.env"

  if not ( $compose_file | path exists ) { error make {msg: $"Compose file ($compose_file) is not found" } }
  if not ( $restic_env_file | path exists ) { error make {msg: $"Restic environment file ($restic_env_file) is not found" } }

  with-tmp-dir $name {|export_dir|
    (
      nu export_container_envs.nu
        --docker-container-name $docker_container_name
        --target-dir $export_dir
    )

    # create backup dump
    (
      docker exec -u git gitea /usr/local/bin/gitea
        dump --work-path /tmp
        --file "gitea-dump.tar.gz"
        --config /etc/gitea/app.ini
        --database sqlite3
        --type tar.gz
    )
    docker cp gitea:"/var/lib/gitea/gitea-dump.tar.gz" "$export_dir"
    docker exec -u git gitea rm -f "/var/lib/gitea/gitea-dump.tar.gz"

    tar -xzf $"($export_dir)/gitea-dump.tar.gz" -C $"($export_dir)/dump"

    with-stopped-docker-container $docker_container_name {
      (
        docker compose -f $compose_file --env-file $restic_env_file
          run --rm --quiet
          --volume $"($export_dir):/data/export"
          restic backup /data --exclude-caches --skip-if-unchanged
      )
    }
  }
}

def main [target: string] {
  backup-to-target $target
}
