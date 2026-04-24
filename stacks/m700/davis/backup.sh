#!/usr/bin/env bash
set -Eeuox pipefail

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
# on_error() {
#   if [[ -n "${current_backup_target}" ]]; then
#     ping_fail "${current_backup_target}" || true
#   fi
# }
# trap on_error ERR

##############
### Main logic
##############

VALID_BACKUP_TARGETS=("local" "onsite", "offsite")
check_target() {
  local target="$1"
  if [[ ! " ${VALID_BACKUP_TARGETS[*]} " =~ " ${target} " ]]; then
    echo "Invalid backup target '${target}'. Valid targets are: ${VALID_BACKUP_TARGETS[*]}" >&2
    return 1
  fi
  return 0
}

check_restic_repository_env_file() {
  local target="$1"
  if [[ ! -f "${target}.restic.env" ]]; then
    echo "Restic environment file '${target}.restic.env' not found for target '${target}'" >&2
    return 1
  fi
  return 0
}

check_restic_repository() {
  local target="$1"

  local exit_code

  RESTIC_ENV_FILE="${target}.restic.env" docker compose -f docker-compose.backup.yaml run --rm restic cat config --json >/dev/null 2>&1 || true
  exit_code=$?

  return "${exit_code}"
}

BACKUP_TARGETS=()
for backup_target in "$@"; do
  # validate backup target
  check_target "${backup_target}"
  exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    # skip this loop
    continue
  fi

  ping_start "${backup_target}"

  # validate restic repository env file and repository access
  check_restic_repository_env_file "${backup_target}"
  exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    ping_fail "${backup_target}"
    continue
  fi

  # 0	Success — repository exists and password is correct
  # 10	Repository does not exist
  # 12	Wrong password
  # 1	Other error
  check_restic_repository "${backup_target}"
  exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    ping_fail "${backup_target}"
    continue
  fi

  BACKUP_TARGETS+=("${backup_target}")
done

bash prepare_backup_data.sh

git_commit="$(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)"

for backup_target in "${BACKUP_TARGETS[@]}"; do

  output="$(docker run --rm -i \
    --name davis-backup-restic \
    --hostname "m700" \
    --user "0:0" \
    --env TZ="Europe/Berlin" \^
    --env RESTIC_CACHE_DIR="/root/.cache/restic" \
    --env-file "${backup_target}.restic.env" \
    -v restic-cache:/root/.cache/restic \
    -v /mnt/data/m700/davis:/repo \
    -v ${DOCKER_VOLUME_NAME}:/data/davis-data:ro \
    -v "${BACKUP_EXPORT_DATA_DIR}":/data/export \
    "${restic_image}" \
    backup /data \
    --tag "git_commit=${git_commit}" --exclude-caches --skip-if-unchanged --json --quiet | jq)"

  exit_code=$?
  ping_result "${backup_target}" "${exit_code}" "${output}" || true

  
  output="$(docker run --rm -i \
    --name davis-backup-restic \
    --hostname "m700" \
    --user "0:0" \
    --env TZ="Europe/Berlin" \
    --env RESTIC_CACHE_DIR="/root/.cache/restic" \
    --env-file "${backup_target}.restic.env" \
    -v restic-cache:/root/.cache/restic \
    -v /mnt/data/m700/davis:/repo \
    -v ${DOCKER_VOLUME_NAME}:/data/davis-data:ro \
    "${restic_image}" \
    check --read-data-subset "33%" --json)"

  exit_code=$?
  ping_result "${backup_target}" "${exit_code}" "${output}" || true


  output="$(docker run --rm -i \
    --name davis-backup-restic \
    --hostname "m700" \
    --user "0:0" \
    --env TZ="Europe/Berlin" \
    --env RESTIC_CACHE_DIR="/root/.cache/restic" \
    --env-file "${backup_target}.restic.env" \
    -v restic-cache:/root/.cache/restic \
    -v /mnt/data/m700/davis:/repo \
    -v appdata:/data/davis-data:ro \
    "${restic_image}" \
    forget --keep-within 365d --quiet)"

  exit_code=$?
  ping_result "${backup_target}" "${exit_code}" "${output}" || true

done
