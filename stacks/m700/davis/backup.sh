#!/usr/bin/env bash
set -Euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

hc_api="${HC_API:?HC_API is required}"
hc_ping_key="${HC_PING_KEY:?HC_PING_KEY is required}"
hc_check_name="${HC_CHECK_NAME:?HC_CHECK_NAME is required}"

readonly WELL_KNOWN_BACKUP_TARGETS=("local" "onsite" "offsite")  # removed stray comma
readonly COMPOSE_FILE="docker-compose.backup.yaml"

run_id="$(cat /proc/sys/kernel/random/uuid)"
hc_base_url="https://${hc_api}/ping/${hc_ping_key}/${hc_check_name}"

# ─── Usage ────────────────────────────────────────────────────────────────────

(( $# > 0 )) || { echo "Usage: $0 <backup-target> [backup-target ...]" >&2; exit 1; }

# ─── Healthchecks helpers ─────────────────────────────────────────────────────

curl_ping() {
  curl -fsS -m 10 --retry 5 -o /dev/null "$@"
}

ping_start() {
  curl_ping "${hc_base_url}-${1}/start?create=1&rid=${run_id}"
}

ping_result() {
  local target="$1" code="$2" payload="$3"
  curl_ping --data-raw "${payload}" "${hc_base_url}-${target}/${code}?rid=${run_id}"
}

ping_fail() {
  curl_ping "${hc_base_url}-${1}/fail?rid=${run_id}"
}

# ─── Validation ───────────────────────────────────────────────────────────────

is_well_known_target() {
  local target="$1"
  local t
  for t in "${WELL_KNOWN_BACKUP_TARGETS[@]}"; do
    [[ "$t" == "$target" ]] && return 0
  done
  echo "Invalid backup target '${target}'. Valid targets: ${WELL_KNOWN_BACKUP_TARGETS[*]}" >&2
  return 1
}

has_restic_env_file() {
  local target="$1"
  [[ -f "${target}.restic.env" ]] && return 0
  echo "Restic env file '${target}.restic.env' not found" >&2
  return 1
}

# Exit codes: 0=ok, 10=repo missing, 12=wrong password, 1=other error
repo_exists() {
  local target="$1"
  RESTIC_ENV_FILE="${target}.restic.env" \
    docker compose -f "$COMPOSE_FILE" run --rm config | jq
}

# ─── Backup execution ─────────────────────────────────────────────────────────

do_restic() {
  local command="$1" target="$2"
  local output exit_code
  output="$(
    RESTIC_ENV_FILE="${target}.restic.env" \
    GIT_SHA="${git_commit}" \
      docker compose -f "$COMPOSE_FILE" run --rm "${command}" | jq
  )"
  exit_code=$?
  ping_result "${target}" "${exit_code}" "${output}"
  return "${exit_code}"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

valid_targets=()

for target in "$@"; do
  is_well_known_target  "$target" || continue
  ping_start       "$target"
  has_restic_env_file     "$target" || { ping_fail "$target"; continue; }
  repo_exists      "$target" || { ping_fail "$target"; continue; }
  valid_targets+=("$target")
done

if (( ${#valid_targets[@]} == 0 )); then
  echo "No valid backup targets to process. Exiting." >&2
  exit 1
fi

echo "Backup targets to be processed: ${valid_targets[*]}"

bash prepare_backup_data.sh

git_commit="$(git ls-remote https://github.com/optimistic-cloud/home-ops.git HEAD | cut -f1)"

for target in "${valid_targets[@]}"; do
  do_restic backup  "$target"
  do_restic forget  "$target"
  do_restic check   "$target"
done
