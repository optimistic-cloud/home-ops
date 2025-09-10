use utils.nu *

def run_docker_container_command [command: string, container_name: string] {
  try {
    let out = ^docker container $command $container_name | complete
    $out | do_logging_for $"Docker container ($command)"
    ignore
  } catch {|err|
    log error $"Error: $(err)"
    error make $err
  }
}

def assert_action [container_name: string] {
  ^docker container inspect $container_name | from json | get 0.State.Status | print
}

def stop_container []: string -> nothing {
  let container_name = $in
  log debug $"Stop docker container ($container_name)"

  run_docker_container_command 'stop' $container_name
  assert_action $container_name
}

def start_container []: string -> nothing {
  let container_name = $in
  log debug $"Start docker container ($container_name)"

  run_docker_container_command 'stop' $container_name
  assert_action $container_name
}

export def main [container_name: string, operation: closure] {
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
