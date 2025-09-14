use std/assert
use utils.nu *

def run_docker_container_command [command: string, container_name: string] {
  try {
    let out = ^docker container $command $container_name | complete
    $out | do_logging_for $"Docker container ($command)"
  } catch {|err|
    log error $"Error: ($err)"
    error make $err
  }
}

def assert_docker_container_action [expected: string] {
  let container_name = $in
  let isValue = ^docker container inspect $container_name | from json | get 0.State.Status

  assert ($isValue == $expected)
}

def stop_container []: string -> nothing {
  let container_name = $in
  log info $"Stop docker container ($container_name)"

  run_docker_container_command 'stop' $container_name
  $container_name | assert_docker_container_action "exited"
}

def start_container []: string -> nothing {
  let container_name = $in
  log debug $"Start docker container ($container_name)"

  run_docker_container_command 'start' $container_name
  $container_name | assert_docker_container_action "running"
}

export def with-docker-volume [--volume_name: string, operation: closure] {
  print $"Creating temporary docker volume... ($volume_name)"
  let volume_name = $volume_name

  try {
      ^docker volume create $volume_name
      $volume_name | do $operation
      ^docker volume rm $volume_name
  } catch {|err|
      ^docker volume rm $volume_name
      log error $"Error: ($err)"
      error make $err
  }
}

export def main [--container_name: string, operation: closure] {
  print $"Stopping docker container... ($container_name)"
  $container_name | stop_container

  try {
      do $operation
      $container_name | start_container
  } catch {|err|
      # https://github.com/nushell/nushell/issues/15279
      $container_name | start_container
      error make $err
  }
}
