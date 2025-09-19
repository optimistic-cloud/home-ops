use ./with-healthcheck.nu *

export def require []: path -> path {
  let file = $in | path expand
  if not ($file | path exists) {
      error make { msg: $"Required file not found: ($file)" }
  }
  $file
}

export def log-debug []: record -> nothing {
  let exit_code = $in.exit_code
  let stdout = $in.stdout
  let stderr = $in.stderr

  let msg = $"exit code: ($in.exit_code), stderr: ($in.stderr), stdout: ($in.stdout)"

  if $exit_code != 0 {
    log error $"Error: ($msg)"
  } else {
    log debug $"($msg)"
  }
}

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
  let file = $in | path expand -s
  let filename = ($file | path basename)

  if (docker volume inspect $volume | complete | get exit_code) != 0 {
    log error $"Docker volume ($volume) does not exist, cannot add file ($file)"
    error make { msg: $"Docker volume ($volume) does not exist" }
  }

  do {
    let da = [
      "-v", $"($volume):/data:rw",
      "-v", $"($file):/import/($filename):ro"
    ]
    let args = ["sh", "-c", $"cp /import/($filename) /data"]

    with-alpine --docker-args $da --args $args
  }
}

export def export-sqlite-database-in-volume [--volume: string, prefix: string = "export"]: record -> nothing {
  let src_volume = $in.src_volume
  let src_path = $in.src_path

  let db_name = $"($prefix)-($src_path | path basename)"

  do {
    let da = [
      "-v", $"($src_volume):/data:ro"
      "-v", $"($volume):/export:rw",
    ]
    let args = [$src_path, $".backup '/export/($db_name)'"]

    with-alpine-sqlite --docker-args $da --args $args
  }

  do {
    let da = [
      "-v", $"($volume):/export:rw",
    ]
    let args = [$"/export/($db_name)", "PRAGMA integrity_check;"]

    with-alpine-sqlite --docker-args $da --args $args
  }

  ignore
}

export def extract-files-from-container [--volume: string, --sub-path: path = '', operation?: closure]: record -> nothing {
  let from_container = $in.from_container
  let paths = $in.paths

  let tmp_dir = (mktemp -d)

  try {
    $paths | each {|p|
	    ^docker cp $"($from_container):($p)" $tmp_dir
    }

    if (ls $tmp_dir | is-empty) {
      error make { msg: "directory is empty"}
    }

    if not ($operation == null) {
      $tmp_dir | do $operation
    }

    let target_path = '/data' | path join $sub_path 

    do {
      let da = [
        "-v", $"($volume):/data:rw",
        "-v", $"($tmp_dir):/import:ro"
      ]
      let args = ["sh", "-c", $"mkdir -p ($target_path) && cp -r /import/* ($target_path)"]

      with-alpine --docker-args $da --args $args
    }
    
    rm -rf $tmp_dir | ignore
   } catch {|err|
      rm -rf $tmp_dir | ignore
      error make $err
   }
}

def export-env-from-container [--volume: string, name?: string]: string -> nothing {
  let container_name = $in
  let env_name = ($name | default $"($container_name).env")

  let env_file = mktemp env_file.XXX

  try {

    ^docker container inspect $container_name | from json | get 0.Config.Env | save --force $env_file

    do {
      let da = [
        "-v", $"($volume):/data:rw",
        "-v", $"($env_file):/import/env:ro"
      ]
      let args = ["sh", "-c", $"cp /import/env /data/($env_name)"]

      with-alpine --docker-args $da --args $args
    }

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

export def backup [--provider-env-files: list<path>]: record -> record {
  if not ($in | columns | any {|col| $col == 'container_name'}) {
    error make { msg: "Mandatory key 'container_name' is missing in input record" }
  }
  if not ($in | columns | any {|col| $col == 'volumes'}) {
    error make { msg: "Mandatory key 'volumes' is missing in input record" }
  }
  
  let container_name = $in.container_name
  let volumes = $in.volumes
  
  if not ($volumes | columns | any {|col| $col == 'config'}) {
    error make { msg: "Mandatory volume with key 'config' is missing" }
  }

  # Export env from container
  $container_name | export-env-from-container --volume $volumes.config

  $provider_env_files | each {|i|
    log debug $"Using provider env file: ($i)"
    let provider_env_file = $i | path expand | require

    $volumes | do-restic-backup --provider-env-file $provider_env_file
    #$volumes | do-kopia-backup
  }
}

def do-restic-backup [--provider-env-file: path]: record -> record {
  let volumes = $in

  # restic backup
  with-ping {
    const backup_path_in_docker_volume = "/backup"

    let docker_args = $volumes
      | items {|key, value| [ "-v" ($value + $":($backup_path_in_docker_volume)/" + ($key | str trim)) ] }
      | flatten

    # Note: --one-file-system is omitted because backup data spans multiple mounts (docker volumes)
    let restic_args = [
      "--json", "--quiet",
      "backup", $backup_path_in_docker_volume,
      "--skip-if-unchanged",
      "--exclude-caches",
      "--tag", $"git_commit=(get-current-git-commit)"
    ]
    
    let $out = $provider_env_file | with-restic --docker-args $docker_args --restic-args $restic_args
    'latest' | assert_snapshot --provider-env-file $provider_env_file

    $out
  }

  # restic check
  with-ping {
    restic check --provider-env-file $provider_env_file
  }

  # restic forget
  with-ping {
    restic forget --provider-env-file $provider_env_file
  }
}

def assert_snapshot [--provider-env-file: path, threshold: duration = 1min]: string -> nothing {
  let snapshot_id = $in

  let out = $provider_env_file | with-restic --docker-args [] --restic-args ["snapshots", $snapshot_id, "--json"]
  $out | log-debug
  if $out.exit_code != 0 {
    error make { msg: "Failed to get snapshots: ($out.stderr)" }
  }
  
  let snapshot_time = $out.stdout | from json | get 0.time | into datetime

  let result = (date now) < ($snapshot_time + $threshold)

  if not $result {
      error make { msg: $"Snapshot assertion failed! Snapshot time: ($snapshot_time), Current time: (date now)" }
  }
}

def generate-docker-args-from-provider []: path -> list<string> {
  let provider_env_file = $in
  let common_args = [
    "--hostname", $env.HOSTNAME,
    "--env-file", $provider_env_file,
    "-v", $"($env.HOME)/.cache/restic:/root/.cache/restic"
    "-e", "TZ=Europe/Berlin"
  ]

  # Check for local repository
  let is_local = $provider_env_file | str contains ".local."
  let local_repository = if $is_local {
    let a = open $provider_env_file
      | lines 
      | where $it starts-with "RESTIC_REPOSITORY=" 
      | str replace "RESTIC_REPOSITORY=" ""
      | first
    [ "-v", ($a + : + $a) ]
  } else {
    []
  }

  let out = $common_args ++ $local_repository
  $out
}

export def "restic init" [--provider-env-file: path] { 
  $provider_env_file | with-restic --docker-args [] --restic-args ["init"]
}

export def "restic stats" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "stats"]
}

export def "restic ls" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "ls", "latest"]
}

export def "restic snapshots" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "snapshots", "--latest", "5"]
}

export def "restic check" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--json", "--quiet", "check", "--read-data-subset", "33%"]
}

export def "restic forget" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "forget", "--prune", "--keep-within", "180d"]
}

export def "restic prune" [--provider-env-file: path] { 
    $provider_env_file | with-restic --docker-args [] --restic-args ["--quiet", "prune"]
}

export def "restic restore" [--provider-env-file: path, --target: path] {
  if ($target | path exists) {
      error make {msg: "Restore path already exists" }
  }

  const restore_path_in_docker_volume = "/data"

  $provider_env_file | with-restic --docker-args ["-v", $"($target):($restore_path_in_docker_volume):rw"] --restic-args ["restore", "latest", "--target", ($restore_path_in_docker_volume)]
  log info $"Restored data is available at: ($target)"
}

export def with-restic [--docker-args: list<string>, --restic-args: list<string>]: path -> record {
  let docker_args_from_provider = $in | generate-docker-args-from-provider
  with-docker-run $env.RESTIC_DOCKER_IMAGE --docker-args ($docker_args_from_provider ++ $docker_args) --args $restic_args
}

def with-alpine [--docker-args: list<string>, --args: list<string>]: nothing -> record {
  const image = "alpine"
  with-docker-run $image --docker-args $docker_args --args $args
}

def with-alpine-sqlite [--docker-args: list<string>, --args: list<string>]: nothing -> record {
  const image = "alpine/sqlite"
  with-docker-run $image --docker-args $docker_args --args $args
}

def with-docker-run [image: string, --docker-args: list<string>, --args: list<string>]: nothing -> record {
  log debug $"Running ($image) with docker args: ($docker_args) and args: ($args)"

  let out = ^docker run --rm -ti ...$docker_args $image ...$args | complete

  $out | log-debug
  $out
}
