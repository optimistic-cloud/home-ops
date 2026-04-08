#!/usr/bin/env bash
set -exuo pipefail

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
