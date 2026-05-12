use std/log

def main [--docker-container-name: string, --target-dir: path] {
  log debug $"Exporting environment variables for container: ($docker_container_name) to directory: ($target_dir)"

  let target_env_file = $"($target_dir)/($docker_container_name).env" | path expand

  docker inspect --format '{{json .Config.Env}}' $docker_container_name 
    | from json 
    | save --force $target_env_file

  # check
  if not ($target_env_file | path exists) {
    error make { msg: $"File ($target_env_file) does not exist" }
  }

  log debug $"Environment variables exported successfully to ($target_env_file)"
  log debug $"($target_env_file) contains (open $target_env_file | lines | length) lines"
}