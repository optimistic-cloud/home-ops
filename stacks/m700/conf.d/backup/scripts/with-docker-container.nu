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

  run_docker_container_command 'stop' $container_name
  $container_name | assert_docker_container_action "exited"
}

def start_container []: string -> nothing {
  let container_name = $in

  run_docker_container_command 'start' $container_name
  $container_name | assert_docker_container_action "running"
}

export def with-tmp-docker-volume [operation: closure]: nothing -> string {
  let name = (random chars --length 4)
  try {
      ^docker volume create $name | ignore
      $name | do $operation
      ^docker volume rm $name | ignore
  } catch {|err|
      ^docker volume rm $name | ignore
      log error $"Error: ($err)"
      error make $err
  }
}

export def main [--name: string, operation: closure] {
  $name | stop_container

  try {
      do $operation
      $name | start_container
  } catch {|err|
      # https://github.com/nushell/nushell/issues/15279
      $name | start_container
      error make $err
  }
}
