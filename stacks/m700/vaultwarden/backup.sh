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

  log=$(just restic-backup "$backup_target")
  exit_code=$?
  ${curl_cmd} --data-raw "${log}" "${hc_base_url}-${backup_target}/${exit_code}?rid=${run_id}"

  log=$(just restic-check "$backup_target")
  exit_code=$?
  ${curl_cmd} --data-raw "${log}" "${hc_base_url}-${backup_target}/${exit_code}?rid=${run_id}"

  log=$(just restic-forget "$backup_target")
  exit_code=$?
  ${curl_cmd} --data-raw "${log}" "${hc_base_url}-${backup_target}/${exit_code}?rid=${run_id}"
done
