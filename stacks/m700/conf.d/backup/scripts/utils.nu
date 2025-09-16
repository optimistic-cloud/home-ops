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
  let file = $in

  if not ($file | path exists) {
    log error $"File ($file) does not exist, cannot add to volume ($volume)"
    error make { msg: $"File ($file) does not exist" }
  }

  let filename = ($file | path basename)

  if (docker volume inspect $volume | complete | get exit_code) != 0 {
    log error $"Docker volume ($volume) does not exist, cannot add file ($file)"
    error make { msg: $"Docker volume ($volume) does not exist" }
  }


  (
    ^docker run --rm -ti 
      -v $"($volume):/data:rw"
      -v $"($file):/import/($filename):ro"
      alpine sh -c 'ls -la /import'

  (
    ^docker run --rm -ti 
      -v $"($volume):/data:rw"
      -v $"($file):/import/($filename):ro"
      alpine sh -c $'mkdir -p /data/misc/ && cp /import/($filename) /data/misc/'
  )
}