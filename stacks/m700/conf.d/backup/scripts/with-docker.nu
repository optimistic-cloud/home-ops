use utils.nu *

def run_docker_container_command [command: string, container_name: string] {
  try {
    let out = ^docker container $command $contaner_name | complete
    $out | do_logging_for "Docker container ($command)"
    ignore
  } catch {|err|
    log error $"Error: $(err)"
    error make $err
  }
}

def stop_container []: string -> nothing {
  let contaner_name = $in
  log debug $"Stop docker container ($contaner_name)"

  run_docker_container_command 'stop' $contaner_name
}

def start_container []: string -> nothing {
  let contaner_name = $in
  log debug $"Start docker container ($contaner_name)"

  run_docker_container_command 'stop' $contaner_name
}

export def main [contaner_name: string, operation: closure] {
  $container_name | stop_container

  try {
      do $operation
      $container_name | start_container
  } catch {|err|
      $container_name | start_container
      error make $err
  }
}
