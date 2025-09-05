#!/usr/bin/env sh
set -euo pipefail

providers="/opt/conf.d/backup/providers"

restic_cmd="restic"
curl_cmd="curl -fsS -m 10 --retry 5 -o /dev/null"

app=$1

ping_url="https://hc-ping.com/${HC_PING_KEY}/${app}-backup"

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

ping_hc() { ${curl_cmd} "${ping_url}${1}?create=1" || true; }

cleanup() { rm -rf "$export_dir"; }
trap cleanup EXIT

error() { ping_hc "/fail"; }
trap error ERR

ping_hc "/start"

rm -rf "$export_dir" && mkdir -p -m 700 "$export_dir"

hooks_sh="/opt/${app}/conf.d/backup/hooks.sh"
if [ -f "${hooks_sh}" ]; then
  source /"${hooks_sh}"
fi

if declare -F pre_backup >/dev/null; then
    pre_backup $backup_dir $export_dir $app
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
  {
    (
      set -a
      source "$file"

      provider=$(basename "$file")

      export RESTIC_REPOSITORY="s3:${OBJECT_STORAGE_API}/abc-test/${app}/restic"
      export RESTIC_PASSWORD_FILE="/opt/${app}/conf.d/backup/secrets/${provider}-restic-password.txt"

      if [ ! -f "${RESTIC_PASSWORD_FILE}" ]; then
        echo "Error: Password file ${RESTIC_PASSWORD_FILE} does not exist."
        exit 1
      fi

      ${restic_cmd} backup \
        --files-from /opt/${app}/conf.d/backup/include.txt \
        --exclude-file /opt/${app}/conf.d/backup/exclude.txt \
        --exclude-caches \
        --one-file-system \
        --tag git_commit=${git_commit}
      
      ${restic_cmd} check --read-data-subset 33%

      test_snapshot

      ${restic_cmd} snapshots latest
      ${restic_cmd} ls latest --long --recursive

      set +a
    )
  } | ${curl_cmd} --data-binary @- "${ping_url}"
done

rm -rf "$export_dir"

if declare -F post_backup >/dev/null; then
    post_backup $backup_dir $export_dir $app
fi

ping_hc ""
