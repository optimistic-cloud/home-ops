#!/usr/bin/env python3
import os, subprocess, sys, uuid
from urllib import request, error
from urllib.request import Request


HC_API        = os.environ["HC_API"]
HC_PING_KEY   = os.environ["HC_PING_KEY"]
HC_CHECK_NAME = os.environ["HC_CHECK_NAME"]

WELL_KNOWN_TARGETS = {"local", "onsite", "offsite"}
COMPOSE_FILE       = "docker-compose.backup.yaml"
RUN_ID             = str(uuid.uuid4())
BASE_URL           = f"https://{HC_API}/ping/{HC_PING_KEY}/{HC_CHECK_NAME}"

def curl_ping(url: str, payload: str | None = None) -> None:
    httpx.post(url, content=payload, timeout=10) if payload else httpx.get(url, timeout=10)

def ping_start(target: str)  -> None: curl_ping(f"{BASE_URL}-{target}/start?create=1&rid={RUN_ID}")
def ping_fail(target: str)   -> None: curl_ping(f"{BASE_URL}-{target}/fail?rid={RUN_ID}")
def ping_result(target: str, code: int, payload: str) -> None:
    curl_ping(f"{BASE_URL}-{target}/{code}?rid={RUN_ID}", payload)

def repo_exists(target: str) -> bool:
    result = subprocess.run(
        ["docker", "compose", "-f", COMPOSE_FILE, "run", "--rm", "config"],
        env={**os.environ, "RESTIC_ENV_FILE": f"{target}.restic.env"},
        capture_output=True
    )
    return result.returncode == 0

def do_restic(target: str, command: str, git_commit: str) -> None:
    result = subprocess.run(
        ["docker", "compose", "-f", COMPOSE_FILE, "run", "--rm", command],
        env={**os.environ, "RESTIC_ENV_FILE": f"{target}.restic.env", "GIT_SHA": git_commit},
        capture_output=True, text=True
    )
    ping_result(target, result.returncode, result.stdout)

def main(targets: list[str]) -> None:
    if not targets:
        sys.exit(f"Usage: {sys.argv[0]} <backup-target> [...]")

    valid_targets = []
    for target in targets:
        if target not in WELL_KNOWN_TARGETS:
            print(f"Invalid target '{target}'", file=sys.stderr)
            continue
        ping_start(target)
        if not os.path.isfile(f"{target}.restic.env"):
            print(f"Missing env file for '{target}'", file=sys.stderr)
            ping_fail(target); continue
        if not repo_exists(target):
            ping_fail(target); continue
        valid_targets.append(target)

    if not valid_targets:
        sys.exit("No valid backup targets. Exiting.")

    print(f"Targets: {', '.join(valid_targets)}")
    subprocess.run(["python3", "prepare_backup_data.py"], check=True)

    git_commit = subprocess.check_output(
        ["git", "ls-remote", "https://github.com/optimistic-cloud/home-ops.git", "HEAD"],
        text=True
    ).split()[0]

    for target in valid_targets:
        for command in ("backup", "forget", "check"):
            do_restic(target, command, git_commit)

if __name__ == "__main__":
    main(sys.argv[1:])
