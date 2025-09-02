#!/usr/bin/env sh
set -euo pipefail

# Acquire lockfile to prevent concurrent execution
lockfile="/tmp/vaultwarden-backup.lock"
exec 200>"$lockfile"
flock -n 200 || { echo "Another backup is running. Exiting."; exit 1; }

backup_dir="/opt/vaultwarden"
export_dir="/tmp/vaultwarden/export"

ping_hc() {
    curl -fsS -m 10 --retry 5 -o /dev/null "https://hc-ping.com/${HC_UUID}${1}?create=1" || true
}

cleanup() { rm -rf "$export_dir"; }
trap cleanup EXIT

error() { ping_hc "/fail"; }
trap error ERR

ping_hc "/start"

rm -rf "$export_dir" && mkdir -p -m 700 "$export_dir"
sqlite3 "$backup_dir/data/db.sqlite3" ".backup '$export_dir/db.sqlite3'"

git_commit=$(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)
restic_version=$(restic version | cut -d ' ' -f2)

# loop over env files end execute
for file in *.env; do
    set -a
    source "$file"
    
    restic --verbose=0 --quiet backup \
      --files-from ./include.txt \
      --exclude-file ./exclude.txt \
      --exclude-caches \
      --one-file-system \
      --tag app=vaultwarden \
      --tag git_commit=${git_commit} \
      --tag restic_version=${restic_version}
    
    restic --verbose=0 --quiet check --read-data-subset 25%

    set +a
done

rm -rf "$export_dir"

ping_hc ""