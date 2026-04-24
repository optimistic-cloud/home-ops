#!/usr/bin/env bash
set -Eeuo pipefail

hc_api="${HC_API:?HC_API is required}"
hc_ping_key="${HC_PING_KEY:?HC_PING_KEY is required}"
hc_check_name="${HC_CHECK_NAME:?HC_CHECK_NAME is required}"

run_id="$(cat /proc/sys/kernel/random/uuid)"
hc_base_url="https://${hc_api}/ping/${hc_ping_key}/${hc_check_name}"
restic_image="restic/restic:0.18.1@sha256:39d9072fb5651c80d75c7a811612eb60b4c06b32ffe87c2e9f3c7222e1797e76"

if [[ "$#" -eq 0 ]]; then
  echo "Usage: $0 <backup-target> [backup-target ...]" >&2
  exit 1
fi

curl_ping() {
  curl -fsS -m 10 --retry 5 -o /dev/null "$@"
}

ping_start() {
  local target="$1"
  curl_ping "${hc_base_url}-${target}/start?create=1&rid=${run_id}"
}

ping_result() {
  local target="$1"
  local code="$2"
  local payload="$3"
  curl_ping --data-raw "${payload}" "${hc_base_url}-${target}/${code}?rid=${run_id}"
}

ping_fail() {
  local target="$1"
  curl_ping "${hc_base_url}-${target}/fail?rid=${run_id}"
}

current_backup_target=""
on_error() {
  if [[ -n "${current_backup_target}" ]]; then
    ping_fail "${current_backup_target}" || true
  fi
}
trap on_error ERR

docker_restic() {
  local target="$1"
  shift

  docker run --rm -i \
    --name davis-backup-restic \
    --hostname "m700" \
    --user "0:0" \
    --env TZ="Europe/Berlin" \
    --env RESTIC_CACHE_DIR="/root/.cache/restic" \
    --env-file "${target}.restic.env" \
    -v restic-cache:/root/.cache/restic \
    -v /mnt/data/m700/davis:/repo \
    -v appdata:/data/davis-data:ro \
    "$@"
}

run_step() {
  local target="$1"
  shift

  local output
  local exit_code

  set +e
  output="$($@ 2>&1)"
  exit_code=$?
  set -e

  ping_result "${target}" "${exit_code}" "${output}" || true

  if [[ "${exit_code}" -ne 0 ]]; then
    ping_fail "${target}" || true
    return "${exit_code}"
  fi
}

for backup_target in "$@"; do
  ping_start "${backup_target}"
done

bash prepare_backup_data.sh

git_commit="$(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)"

for backup_target in "$@"; do
  current_backup_target="${backup_target}"

  run_step "${backup_target}" bash -c '
    docker run --rm -i \
      --name davis-backup-restic \
      --hostname "m700" \
      --user "0:0" \
      --env TZ="Europe/Berlin" \
      --env RESTIC_CACHE_DIR="/root/.cache/restic" \
      --env-file "${1}.restic.env" \
      -v restic-cache:/root/.cache/restic \
      -v /mnt/data/m700/davis:/repo \
      -v appdata:/data/davis-data:ro \
      -v "${BACKUP_EXPORT_DATA_DIR}":/data/export \
      "${2}" \
      backup /data \
      --tag "git_commit=${3}" --exclude-caches --skip-if-unchanged --json --quiet | jq
  ' _ "${backup_target}" "${restic_image}" "${git_commit}"

  run_step "${backup_target}" \
    docker_restic "${backup_target}" \
    "${restic_image}" \
    check --read-data-subset "33%" --json

  run_step "${backup_target}" \
    docker_restic "${backup_target}" \
    "${restic_image}" \
    forget --keep-within 365d --quiet
done
