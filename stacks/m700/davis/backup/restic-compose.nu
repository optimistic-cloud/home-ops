
def main [target: string] -> list<string> {
  let compose_file = $"compose.($target).yaml"
  if not ( $compose_file | path exists ) { error make {msg: $"Compose file ($compose_file) is not found" } }

  let env_file_args = if $target == "local" {
    []
  } else {
    let restic_env_file = $"($target).restic.env"
    if not ( $restic_env_file | path exists ) { error make {msg: $"Restic environment file ($restic_env_file) is not found" } }
    ["--env-file" $restic_env_file]
  }

  ["-f" $compose_file] ++ $env_file_args
}
