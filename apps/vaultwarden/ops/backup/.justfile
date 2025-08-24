set quiet

alias s := snapshots
alias r := restore
alias b := backup

backup_dir := "/data"               # directory containing original application data for backup
staging_dir := "/tmp/backup"        # directory containing prepared application data and exported data for backup

restic_cmd := "/usr/bin/restic --verbose=0 --quiet"
curl_cmd := "curl -fsS -m 10 --retry 5"

# This help message
help:
    just --list

[group('commands')]
[doc('List files in a snapshot from a repository. Supports "latest" as snapshot_id')]
ls repository snapshot_id:
    just --dotenv-filename {{repository}}.env restic-ls {{snapshot_id}}

[group('commands')]
[doc('Initialize a new repository')]
init repository: (check repository)
    just --dotenv-filename {{repository}}.env restic-init

[group('commands')]
[doc('Run complete backup workflow')]
backup repository: (check repository)
    just --dotenv-filename {{repository}}.env restic-workflow

[group('commands')]
[doc('Get latest n snapshots for a repository')]
snapshots repository n="1": (check repository)
    just --dotenv-filename {{repository}}.env restic-snapshots {{n}}

[group('commands')]
[doc('Get stats for a repository')]
stats repository: (check repository)
    just --dotenv-filename {{repository}}.env restic-stats

[group('commands')]
[doc('Restore a snapshot from a repository. Supports "latest" as snapshot_id')]
restore repository snapshot_id target_dir: (check repository)
    just --dotenv-filename {{repository}}.env restic-restore {{snapshot_id}} {{target_dir}}

[private]
restic-workflow: (ping "/start") restic-backup restic-forget restic-check && ping

[group('restic')]
[private]
restic-init:
    {{restic_cmd}} init

[group('restic')]
[private]
restic-ls snapshot_id:
    {{restic_cmd}} ls {{snapshot_id}}

[group('restic')]
[private]
restic-backup: pre-backup && (cleanup staging_dir)
    {{restic_cmd}} backup {{staging_dir}} \
        --exclude-caches --one-file-system \
        --tag app='vaultwarden' \
        --tag vaultwarden_version=`{{curl_cmd}} http://vaultwarden/api/config | jq -r ".version"` \
        --tag restic_version=`restic version | cut -d ' ' -f2`

[group('restic')]
[private]
restic-forget keep_within="180d":
    {{restic_cmd}} forget --prune --keep-within={{keep_within}}

[group('restic')]
[private]
restic-check subset="25%":
    {{restic_cmd}} check --read-data-subset {{subset}}

[group('restic')]
[private]
restic-snapshots n:
    {{restic_cmd}} snapshots --latest {{n}}

[group('restic')]
[private]
restic-stats:
    {{restic_cmd}} stats

[group('restic')]
[private]
restic-restore snapshot_id target_dir:
    echo "Restoring snapshot {{snapshot_id}} to {{target_dir}}"
    rm -rf {{target_dir}}/*
    {{restic_cmd}} restore {{snapshot_id}}:{{staging_dir}} --target {{target_dir}}

[group('maintenance')]
[doc('healthcheck.io ping')]
[private]
ping endpoint="":
    {{curl_cmd}} -o /dev/null "https://hc-ping.com/{{env('HC_UUID')}}{{endpoint}}?create=1"

[group('maintenance')]
[doc('Prepare export directory and backup database')]
[private]
pre-backup: (cleanup staging_dir)
    mkdir -p -m 700 {{staging_dir}}
    rsync -a --delete --exclude 'tmp/' --exclude 'db.sqlite3*' {{backup_dir}}/ {{staging_dir}}
    rsync -a --delete /vaultwarden.env {{staging_dir}}
    sqlite3 {{backup_dir}}/db.sqlite3 ".backup '{{staging_dir}}/db.sqlite3'"

[group('maintenance')]
[doc('Cleanup temporary directories')]
[private]
cleanup dir:
    rm -rf {{dir}}

[group('maintenance')]
[private]
check repository:
    #/usr/bin/env bash
    [ -f "{{repository}}.env" ] || { echo "file {{repository}}.env not found" >&2; exit 1; }
