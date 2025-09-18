use ./with-healthcheck.nu *

export def require []: path -> path {
  let file = $in | path expand
  if not ($file | path exists) {
      error make {
          msg: $"Required file not found: ($file)"
      }
  }
  $file
}

export def log-debug []: record -> nothing {
  let exit_code = $in.exit_code
  let stdout = $in.stdout
  let stderr = $in.stderr

  if $exit_code != 0 {
    log error $"Error: ($stderr) \n($stdout)"
  } else {
    log debug $"($stdout)"
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

def export-env-from-container [--volume: string, name: string = "container.env"]: string -> nothing {
  let container_name = $in

  let env_file = mktemp env_file.XXX

  try {

    ^docker container inspect $container_name | from json | get 0.Config.Env | save --force $env_file

    let da = [
      "-v", $"($volume):/data:rw",
      "-v", $"($env_file):/import/env:ro"
    ]
    let args = ["sh", "-c", $"cp /import/env /data/($name)"]

    with-alpine --docker-args $da --args $args

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

export def backup [--provider-env-file: path]: record -> record {
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

  # Run backup with ping
  with-ping {
    let out = $volumes | restic-backup --provider-env-file $provider_env_file
    'latest' | assert_snapshot --provider-env-file $provider_env_file
    $out
  }

  # Run check with ping
  with-ping {
    # TODO: refactor to check the json and for errors
    restic-check --provider-env-file $provider_env_file
  }
}

def restic-backup [--provider-env-file: path]: record -> record {
  let envs = $provider_env_file | path expand | require

  let volumes = $in

  const backup_path = "/backup"
  
  let vol_flags = $volumes
    | items {|key, value| [ "-v" ($value + $":($backup_path)/" + ($key | str trim)) ] }
    | flatten

  let da = [
    "--hostname", $env.HOSTNAME,
    "--env-file", $provider_env_file,
    ...$vol_flags,
    "-v", $"($env.HOME)/.cache/restic:/root/.cache/restic",
    "-e", "TZ=Europe/Berlin"
  ]
  # Note: --one-file-system is omitted because backup data spans multiple mounts (docker volumes)
  let ra = [
    "--json", "--quiet", 
    "backup", $backup_path, 
    "--skip-if-unchanged", 
    "--exclude-caches", 
    "--tag", $"git_commit=(get-current-git-commit)"]

  with-restic --docker-args $da --restic-args $ra
}

def restic-check [--provider-env-file: path, --subset: string = "33%"]: nothing -> record {
  let envs = $provider_env_file | path expand | require

  let da = [
    "--env-file", $provider_env_file,
    "-v", $"($env.HOME)/.cache/restic:/root/.cache/restic"
  ]
  let ra = ["--json", "--quiet", "check", "--read-data-subset", $subset]

  with-restic --docker-args $da --restic-args $ra
}

export def restic-restore [--provider-env-file: path, --target: path] {
  let envs = $provider_env_file | path expand | require

  let da = [
    "--env-file", $provider_env_file,
    "-v", $"($target):/data:rw",
    "-v", $"($env.HOME)/.cache/restic:/root/.cache/restic"
  ]
  let ra = ["restore", "latest", "--target", "/data"]

  with-restic --docker-args $da --restic-args $ra

  log info $"Restored data is available at: ($target)"
}

def assert_snapshot [--provider-env-file: path, threshold: duration = 1min]: string -> nothing {
  let snapshot_id = $in

  let out = with-restic --docker-args ["--env-file", $provider_env_file] --restic-args ["snapshots", $snapshot_id, "--json"]
  if $out.exit_code != 0 {
    error make { msg: "Failed to get snapshots: ($out.stderr)" }
  }
  
  let snapshot_time = $out.stdout | from json | get 0.time | into datetime

  let result = (date now) < ($snapshot_time + $threshold)

  if not $result {
      error make { msg: $"Snapshot assertion failed! Snapshot time: ($snapshot_time), Current time: (date now)" }
  }
}

export def with-restic [--docker-args: list<string>, --restic-args: list<string>]: nothing -> record {
  # log debug $"Running restic with docker args: ($docker_args) and restic args: ($restic_args)"
  
  # let out = ^docker run --rm -ti ...$docker_args $restic_docker_image ...$restic_args | complete

  # $out | log-debug
  # $out

  with-docker-run $restic_docker_image --docker-args $docker_args --args $args
}

def with-alpine [--docker-args: list<string>, --args: list<string>]: nothing -> record {
  # log debug $"Running alpine with docker args: ($docker_args) and args: ($args)"

  # let out = ^docker run --rm -ti ...$docker_args alpine ...$args | complete

  # $out | log-debug
  # $out

  with-docker-run "alpine" --docker-args $docker_args --args $args
}

def with-alpine-sqlite [--docker-args: list<string>, --args: list<string>]: nothing -> record {
  # log debug $"Running alpine/sqlite with docker args: ($docker_args) and args: ($args)"

  # let out = ^docker run --rm -ti ...$docker_args alpine/sqlite ...$args | complete

  # $out | log-debug
  # $out

  with-docker-run "alpine/sqlite" --docker-args $docker_args --args $args 
}
def with-docker-run [image: string, --docker-args: list<string>, --args: list<string>]: nothing -> record {
  log debug $"Running ($image) with docker args: ($docker_args) and args: ($args)"

  let out = ^docker run --rm -ti ...$docker_args $image ...$args | complete

  $out | log-debug
  $out
}