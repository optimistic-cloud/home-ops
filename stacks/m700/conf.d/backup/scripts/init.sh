#!/usr/bin/env sh
set -euo pipefail

providers="/opt/conf.d/backup/providers"

restic_cmd="restic --verbose=0 --quiet"

app=$1

for file in ${providers}/*.env; do
  [ -f "$file" ] || continue
  (
    set -a
    source "$file"

    export RESTIC_REPOSITORY="s3:${OBJECT_STORAGE_API}/abc-test/${app}/restic"
    export RESTIC_PASSWORD_FILE="/opt/${app}/conf.d/backup/secrets/restic-password.txt"

    ${restic_cmd} init
    
    set +a
  )
done
