export def do_logging_for [command: string]: record -> nothing {
  let exit_code = $in.exit_code
  let stdout = $in.stdout
  let stderr = $in.stderr

  if $exit_code != 0 {
    log error $"($command) failed with exit code ($exit_code) and message: \n($stderr)"
  } else {
    log debug $"($command) done successfully with message: \n($stdout)"
  }
}

export def add-file-to-volume [--volume: string]: path -> nothing {
  let file = $in | path expand
  let filename = ($file | path basename)

  if not ($file | path exists) {
    log error $"File ($file) does not exist, cannot add to volume ($volume)"
    error make { msg: $"File ($file) does not exist" }
  }

  if (docker volume inspect $volume | complete | get exit_code) != 0 {
    log error $"Docker volume ($volume) does not exist, cannot add file ($file)"
    error make { msg: $"Docker volume ($volume) does not exist" }
  }

  (
    ^docker run --rm -ti 
      -v $"($volume):/data:rw"
      -v $"($file):/import/($filename):ro"
      alpine sh -c $'cp /import/($filename) /data'
  )
}

export def export-sqlite-database-in-volume [--volume: string]: record -> nothing {
  let src_volume = $in.src_volume
  let src_path = $in.src_path

  let db_name = ($src_path | path basename)

  (
    ^docker run --rm 
        -v $"($src_volume):/data:ro"
        -v $"($volume):/export:rw"
        alpine/sqlite $src_path $".backup '/export/($db_name)'"
  )

  (
    ^docker run --rm 
        -v $"($volume):/export:rw"
        alpine/sqlite $"/export/($db_name)" "PRAGMA integrity_check;"
  ) | ignore

  ignore
}

export def copy-file-from-container-to-volume []: record -> nothing {
  let container = $in.container
  let dest_volume = $in.dest_volume
  let src_path = $in.src_path
  let dest_path = $in.dest_path

  let tmp_dir = (mktemp -d)

  try { 
    ^docker $"cp ($container):($src_path) ($tmp_dir)" | ignore

    (
      # TODO: needs rework tar component
      ^docker run --rm -ti
          -v $"($tmp_dir):/data:ro"
          -v $"($dest_volume):/export:rw"
          alpine sh -c $"cd /data && tar -xvzf /export/($dest_path)" 
    )
    
    rm -rf $tmp_dir | ignore
   } catch {|err|
      rm -rf $tmp_dir | ignore
   }
}

export def export-env-from-container-to-volume [--volume: string]: string -> nothing {
  let container_name = $in

  let env_file = mktemp env_file.XXX

  try {
    ^docker exec $container_name printenv | save --force $env_file

    (
      ^docker run --rm -ti 
        -v $"($volume):/data:rw"
        -v $"($env_file):/import/env:ro"
        alpine sh -c 'cp /import/env /data/env'
    )

    rm $env_file
    
    ignore
  } catch {|err|
    rm $env_file | ignore
    error make $err
  }
}

export def get-current-git-commit []: nothing -> string {
  (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)
}

const restic_docker_image = "restic/restic:0.18.0"

export def restic-backup [volumes: record]: path -> nothing {
  let env_file = $in | path expand

  # build -v flags where keys are docker volume names and values are mount paths
  let vol_flags = $volumes | items {|key, value| $'-v ($value):/backup/($key):ro' }

  let a = $vol_flags | str join " "
  print $" ($a) "

  (
    ^docker run --rm -ti 
      --env-file $env_file 
      ...$vol_flags
      -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
      -e TZ=Europe/Berlin
      $restic_docker_image --json --quiet backup /backup
              --skip-if-unchanged
              --exclude-caches
              --tag=$"git_commit=(get-current-git-commit)"
  )
}

export def restic-check [--subset: string = "33%"]: path -> nothing {
  let env_file = $in | path expand

  (
    ^docker run --rm -ti
        --env-file $env_file
        $restic_docker_image --json --quiet check --read-data-subset $subset
  )
}

# backup is done for a single volume

# usecases:
# - backup file from container
#   - src container     
#   - backup volume
#   => function: copy-file-from-container-to-volume
# - backup env from container
#   - src container     
#   - backup volume
#   => function: export-env-from-container-to-volume
# - backup sqlite database
#   - src volume
#   - backup volume
#   => function: export-sqlite-database-in-volume
# - backup volume
#   - volume
#   => function: no