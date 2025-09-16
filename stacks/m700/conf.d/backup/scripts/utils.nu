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

export def add-file-to-volume [volume: string]: path -> nothing {
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

export def export-sqlite-database-in-volume []: record -> nothing {
  let src_volume = $in.src_volume
  let dest_volume = $in.dest_volume
  let src_path = $in.src_path
  let dest_path = $in.dest_path

  (
    ^docker run --rm 
        -v $"($src_volume):/data:ro"
        -v $"($dest_volume):/export:rw"
        alpine/sqlite $src_path $".backup '($dest_path)'"
  )
  (
    ^docker run --rm 
        -v $"($dest_volume):/export:rw"
        alpine/sqlite /export/db.sqlite3 "PRAGMA integrity_check;" | ignore
  )
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

export def export-env-from-container-to-volume []: record -> nothing {
  let container = $in.container
  let dest_volume = $in.dest_volume

  $dest_volume | print

  #^docker exec $in.container printenv | save $"($dest_volume)/env" | ignore
}

export def get-current-git-commit []: nothing -> string {
  (git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)
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