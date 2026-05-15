use std/log

def main [target: string, snapshot-id: string] {
  let target_dir = (^mktemp -d $"/tmp/($name)-backup-XXXXXX" | str trim)

  ^just restore $target $snapshot_id $target_dir

  cp ../.env ./$target_dir/
  cp ../.docker-compose.yaml ./$target_dir/
  cp ../Justfile ./$target_dir/

  docker compose -f ./$target_dir/.docker-compose.yaml --env-file ./$target_dir/.env
    run --rm --quiet
    --volume $"./$target_dir:/data"

}
