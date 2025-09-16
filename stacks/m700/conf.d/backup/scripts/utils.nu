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

export def export-sqlite-database-in-volume [--volume: string, prefix: string = "export"]: record -> nothing {
  let src_volume = $in.src_volume
  let src_path = $in.src_path

  let db_name = $"($prefix)-($src_path | path basename)"

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

export def extract-file-from-container [--volume: string, --sub-path: path = '/', operation?: closure]: record -> nothing {
  let from_container = $in.from_container
  let file_to_extract = $in.file_to_extract

  let tmp_dir = (mktemp -d)

  try { 
    ^docker cp $"($from_container):($file_to_extract)" $tmp_dir

    if not ($operation == null) {
      $tmp_dir | do $operation
    }

    print 1
    print /data | path join $sub_path
    let target_path = /data | path join $sub_path
    print $target_path    

    (
      ^docker run --rm -ti 
        -v $"($volume):/data:rw"
        -v $"($tmp_dir):/import:ro"
        alpine sh -c $'cp -r /import/* ($target_path)'
    ) | complete | print
    
    rm -rf $tmp_dir | ignore
   } catch {|err|
      rm -rf $tmp_dir | ignore
      error make $err
   }
}

export def export-env-from-container [--volume: string]: string -> nothing {
  let container_name = $in

  let env_file = mktemp env_file.XXX

  try {
    ^docker container inspect $container_name | from json | get 0.Config.Env | save --force $env_file

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

export def restic-backup [--env-file: path]: record -> record {
  let envs = $env_file | path expand
  let volumes = $in

  const backup_path = "/backup"
  
  let vol_flags = $volumes
    | items {|key, value| [ "-v" ($value + $":($backup_path)/" + ($key | str trim)) ] }
    | flatten

  # Note: --one-file-system is omitted because backup data spans multiple mounts (docker volumes)
  (
    ^docker run --rm -ti 
      --env-file $envs ...$vol_flags
      -v $"($env.HOME)/.cache/restic:/root/.cache/restic"
      -e TZ=Europe/Berlin
      $restic_docker_image --json --quiet backup $backup_path
        --skip-if-unchanged
        --exclude-caches
        --tag=$"git_commit=(get-current-git-commit)"
      | complete
  )
}

export def restic-check [--env-file: path, --subset: string = "33%"]: nothing -> record {
  let envs = $env_file | path expand

  (
    ^docker run --rm -ti 
      --env-file $envs 
      $restic_docker_image --json --quiet check --read-data-subset $subset
      | complete
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