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

    $volumes | do-restic-backup $provider_env_file
    #$volumes | do-kopia-backup
  }
}

def do-restic-backup [--provider-env-file: path]: record -> record {
  let volumes = $in

  # restic backup
  with-ping {
    let out = $volumes | restic-backup --provider-env-file $provider_env_file
    'latest' | assert_snapshot --provider-env-file $provider_env_file
    $out
  }

  # restic check
  with-ping {
    # TODO: refactor to check the json and for errors
    restic-check --provider-env-file provider_env_file
  }
}

def restic-backup [--provider-env-file: path]: record -> record {
  #let envs = $provider_env_file | path expand 
  let volumes = $in

  const backup_path = "/backup"
  
  let vol_flags = $volumes
    | items {|key, value| [ "-v" ($value + $":($backup_path)/" + ($key | str trim)) ] }
    | flatten

  do {
    let docker-args-from-provider = $provider_env_file | generate-docker-args-from-provider
    let da = [
      "--hostname", $env.HOSTNAME,
      ...$vol_flags,
    ]
    # Note: --one-file-system is omitted because backup data spans multiple mounts (docker volumes)
    let ra = [
      "--json", "--quiet", 
      "backup", $backup_path, 
      "--skip-if-unchanged", 
      "--exclude-caches", 
      "--tag", $"git_commit=(get-current-git-commit)"]

    with-restic --docker-args ($docker-args-from-provider ++ $da) --restic-args $ra
  }
}

def restic-check [--provider-env-file: path, --subset: string = "33%"]: nothing -> record {
  let envs = $provider_env_file | path expand | require

  let docker-args-from-provider = $provider_env_file | generate-docker-args-from-provider
  let ra = ["--json", "--quiet", "check", "--read-data-subset", $subset]

  with-restic --docker-args $docker-args-from-provider --restic-args $ra
}

export def restic-restore [--provider-env-file: path, --target: path] {
  let envs = $provider_env_file | path expand | require

  let docker-args-from-provider = $provider_env_file | generate-docker-args-from-provider
  let da = [
    "-v", $"($target):/data:rw",
  ]
  let ra = ["restore", "latest", "--target", "/data"]

  with-restic --docker-args ($docker-args-from-provider ++ $da) --restic-args $ra

  log info $"Restored data is available at: ($target)"
}

def assert_snapshot [--provider-env-file: path, threshold: duration = 1min]: string -> nothing {
  let snapshot_id = $in

  let docker-args-from-provider = $provider_env_file | generate-docker-args-from-provider
  let ra = ["snapshots", $snapshot_id, "--json"]

  let out = with-restic --docker-args $docker-args-from-provider --restic-args $ra
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
  
  let common-args = [
    "--env-file", $provider_env_file,
    "-v", $"($env.HOME)/.cache/restic:/root/.cache/restic"
    "-e", "TZ=Europe/Berlin"
  ]

  # Check for local repository
  let is_local = $provider_config | str contains ".local."
  let local_repository = if $is_local {
    open $provider_config
      | lines 
      | where $it starts-with "RESTIC_REPOSITORY=" 
      | str replace "RESTIC_REPOSITORY=" ""
      | first
      | [ "-v", ($it + : + $it) ]
  } else {
    []
  }

  let out = $common-args ++ $local_repository
  $out | print
  $out
}

export def with-restic [--docker-args: list<string>, --restic-args: list<string>]: nothing -> record {
  with-docker-run $env.RESTIC_DOCKER_IMAGE --docker-args $docker_args --args $restic_args
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
