#!/usr/bin/env bash
set -exuo pipefail

hc_api="${HC_API:?HC_API is required}"
hc_ping_key="${HC_PING_KEY:?HC_PING_KEY is required}"

run_id=$(cat /proc/sys/kernel/random/uuid)
hc_check_base_name=vaultwarden
hc_base_url="https://${hc_api}/ping/${hc_ping_key}/${hc_check_base_name}"
curl_cmd="curl -fsS -m 10 --retry 5 -o /dev/null"

# ping start
for backup_target in "$@"; do
${curl_cmd} "${hc_base_url}-${backup_target}/start?create=1&rid=${run_id}"
done

bash prepare_backup_data.sh

for backup_target in "$@"; do
  on_error() {
    ${curl_cmd} "${hc_base_url}-${backup_target}/fail?rid=${run_id}"
  }
  trap on_error ERR

  git_commit=$(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)
  log=$(docker run --rm -it \
    --name vaultwarden-backup-restic \
    --hostname "m700" \
    --user "0:0" \
    --env TZ="Europe/Berlin" \
    --env RESTIC_CACHE_DIR="/root/.cache/restic" \
    --env-file "${backup_target}.restic.env"  \
    -v restic-cache:/root/.cache/restic \
    -v /mnt/data/m700/vaultwarden:/repo \
    -v vaultwarden-data:/data/vaultwarden-data:ro \
    -v "${EXPORT_DATA}":/data/export \
    -v "${RESTORE_DATA}":/restore-data \
    restic/restic:0.18.1@sha256:39d9072fb5651c80d75c7a811612eb60b4c06b32ffe87c2e9f3c7222e1797e76 \
    backup /data \
    --tag "git_commit=${git_commit}" --exclude-caches --skip-if-unchanged --json --quiet | jq)

  exit_code=$?
  ${curl_cmd} --data-raw "${log}" "${hc_base_url}-${backup_target}/${exit_code}?rid=${run_id}"

  log=$(docker run --rm -it \
    --name vaultwarden-backup-restic \
    --hostname "m700" \
    --user "0:0" \
    --env TZ="Europe/Berlin" \
    --env RESTIC_CACHE_DIR="/root/.cache/restic" \
    --env-file "${backup_target}.restic.env"  \
    -v restic-cache:/root/.cache/restic \
    -v /mnt/data/m700/vaultwarden:/repo \
    -v vaultwarden-data:/data/vaultwarden-data:ro \
    restic/restic:0.18.1@sha256:39d9072fb5651c80d75c7a811612eb60b4c06b32ffe87c2e9f3c7222e1797e76 \
    check \
    --read-data-subset "33%" --json)
  exit_code=$?
  ${curl_cmd} --data-raw "${log}" "${hc_base_url}-${backup_target}/${exit_code}?rid=${run_id}"

  log=$(docker run --rm -it \
    --name vaultwarden-backup-restic \
    --hostname "m700" \
    --user "0:0" \
    --env TZ="Europe/Berlin" \
    --env RESTIC_CACHE_DIR="/root/.cache/restic" \
    --env-file "${backup_target}.restic.env"  \
    -v restic-cache:/root/.cache/restic \
    -v /mnt/data/m700/vaultwarden:/repo \
    -v vaultwarden-data:/data/vaultwarden-data:ro \
    restic/restic:0.18.1@sha256:39d9072fb5651c80d75c7a811612eb60b4c06b32ffe87c2e9f3c7222e1797e76 \
    forget --keep-within 365d --quiet)
  exit_code=$?
  ${curl_cmd} --data-raw "${log}" "${hc_base_url}-${backup_target}/${exit_code}?rid=${run_id}"
done
