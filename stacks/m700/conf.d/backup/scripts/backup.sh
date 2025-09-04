#!/usr/bin/env sh
set -euo pipefail

providers="/opt/conf.d/backup/providers"

restic_cmd="restic --verbose=0 --quiet"
curl_cmd="curl -fsS -m 10 --retry 5"

app=$1

if [ ! -f "/opt/${app}/conf.d/backup/include.txt" ]; then
  echo "Error: Include file /opt/${app}/conf.d/backup/include.txt does not exist."
  exit 1
fi

if [ ! -f "/opt/${app}/conf.d/backup/exclude.txt" ]; then
  echo "Error: Exclude file /opt/${app}/conf.d/backup/exclude.txt does not exist."
  exit 1
fi

# Acquire lockfile to prevent concurrent execution
lockfile="/tmp/${app}-backup.lock"
exec 200>"$lockfile"
flock -n 200 || { echo "Another backup is running. Exiting."; exit 1; }

backup_dir="/opt/${app}"
export_dir="/tmp/${app}/export"

ping_hc() { ${curl_cmd} -o /dev/null "https://hc-ping.com/${HC_PING_KEY}/${app}-backup${1}?create=1" || true; }

cleanup() { rm -rf "$export_dir"; }
trap cleanup EXIT

error() { ping_hc "/fail"; }
trap error ERR

ping_hc "/start"

rm -rf "$export_dir" && mkdir -p -m 700 "$export_dir"

if [ -f "/opt/${app}/conf.d/backup/backup-export.sh" ]; then
  source /opt/${app}/conf.d/backup/backup-export.sh
  export_data $backup_dir $export_dir $app
fi

git_commit=$(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)

test_snapshot() {
  snapshot_time=$(${restic_cmd} snapshots latest --json | jq -r '.[0].time' | cut -d'.' -f1)
  snapshot_time_fixed=${snapshot_time/T/ }
  snapshot_epoch=$(date -d "$snapshot_time_fixed" "+%s")

  current_epoch=$(date +%s)

  diff=$(( current_epoch - snapshot_epoch ))
  diff=${diff#-}

  threshold=600

  if [ "$diff" -gt "$threshold" ]; then
    exit 2
  fi
}

for file in ${providers}/*.env; do
  [ -f "$file" ] || continue
  [ "$(basename "$file")" = "example.env" ] && continue
  (
    set -a
    source "$file"

    export RESTIC_REPOSITORY="s3:${OBJECT_STORAGE_API}/abc-test/${app}/restic"
    export RESTIC_PASSWORD_FILE="/opt/${app}/conf.d/backup/secrets/restic-password.txt"
    # TODO: RESTIC_PASSWORD_CMD

    ${restic_cmd} backup \
      --files-from /opt/${app}/conf.d/backup/include.txt \
      --exclude-file /opt/${app}/conf.d/backup/exclude.txt \
      --exclude-caches \
      --one-file-system \
      --tag app=${app} \
      --tag git_commit=${git_commit}
    
    ${restic_cmd} check --read-data-subset 100%

    test_snapshot
    
    set +a
  )
done

rm -rf "$export_dir"

ping_hc ""
