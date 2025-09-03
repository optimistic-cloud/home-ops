#!/usr/bin/env sh
set -euo pipefail

app=gitea

# Acquire lockfile to prevent concurrent execution
lockfile="/tmp/${app}-backup.lock"
exec 200>"$lockfile"
flock -n 200 || { echo "Another backup is running. Exiting."; exit 1; }

restic_cmd="restic --verbose=0 --quiet"
curl_cmd="curl -fsS -m 10 --retry 5"

backup_dir="/opt/${app}"
export_dir="/tmp/${app}/export"

ping_hc() { ${curl_cmd} -o /dev/null "https://hc-ping.com/${HC_PING_KEY}/${app}${1}?create=1" || true; }

cleanup() { rm -rf "$export_dir"; }
trap cleanup EXIT

error() { ping_hc "/fail"; }
trap error ERR

ping_hc "/start"

rm -rf "$export_dir" && mkdir -p -m 700 "$export_dir"
sqlite3 "$backup_dir/data/db.sqlite3" ".backup '$export_dir/db.sqlite3'"

git_commit=$(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)
restic_version=$(restic version | cut -d ' ' -f2)

for file in *.env; do
  [ -f "$file" ] || continue
  (
    set -a
    source "$file"
    
    ${restic_cmd} backup \
      --files-from ./include.txt \
      --exclude-file ./exclude.txt \
      --exclude-caches \
      --one-file-system \
      --tag app=${app} \
      --tag git_commit=${git_commit} \
      --tag restic_version=${restic_version}
    
    ${restic_cmd} check --read-data-subset 100%

    set +a
  )
done

rm -rf "$export_dir"

ping_hc ""
