#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: member-preflight.sh --repo <repo> [options]

Options:
  --org <org>              GitHub organization (default: Ma-Lab2)
  --repo <repo>            Repository name (required)
  --ssh-host <host>        SSH host alias in ~/.ssh/config (default: github.com)
  --token-env <ENV>        Token env var name (default: GH_TOKEN)
  --out <path>             JSON output path (default: ./member-preflight.json)
  -h, --help               Show help

Example:
  member-preflight.sh --org Ma-Lab2 --repo Pytps-web --ssh-host github-small
USAGE
}

ORG="Ma-Lab2"
REPO=""
SSH_HOST="github.com"
TOKEN_ENV="GH_TOKEN"
OUT_JSON="./member-preflight.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)
      ORG="$2"
      shift 2
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    --ssh-host)
      SSH_HOST="$2"
      shift 2
      ;;
    --token-env)
      TOKEN_ENV="$2"
      shift 2
      ;;
    --out)
      OUT_JSON="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$REPO" ]]; then
  echo "[ERROR] --repo is required"
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONBOARD_SCRIPT="$SCRIPT_DIR/onboarding-check.sh"
if [[ ! -x "$ONBOARD_SCRIPT" ]]; then
  echo "[ERROR] Missing executable script: $ONBOARD_SCRIPT"
  exit 1
fi

TMP_ONBOARD_JSON="$(mktemp)"

if "$ONBOARD_SCRIPT" --org "$ORG" --repo "$REPO" --ssh-host "$SSH_HOST" --token-env "$TOKEN_ENV" --out "$TMP_ONBOARD_JSON" >/tmp/member-preflight.onboarding.log 2>&1; then
  :
else
  :
fi

TOKEN="${!TOKEN_ENV:-}"

python3 - "$TMP_ONBOARD_JSON" "$OUT_JSON" "$ORG" "$REPO" "$SSH_HOST" "$TOKEN" <<'PY'
import json
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

onboard_path, out_path, org, repo, ssh_host, token = sys.argv[1:]
payload = json.loads(Path(onboard_path).read_text(encoding="utf-8"))
checks = list(payload.get("checks", []))


def add(check_id: str, status: str, message: str) -> None:
    checks.append({"id": check_id, "status": status, "message": message})


def gh_get(url: str, token_value: str):
    req = urllib.request.Request(
        url=url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token_value}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "member-preflight",
        },
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def run(cmd):
    return subprocess.run(cmd, text=True, capture_output=True)

ssh_url = f"git@{ssh_host}:{org}/{repo}.git"
default_branch = None

if token:
    try:
        repo_info = gh_get(
            f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}",
            token,
        )
        default_branch = repo_info.get("default_branch")
        if default_branch:
            add("repo_default_branch", "PASS", f"Default branch via GitHub API: {default_branch}")
        else:
            add("repo_default_branch", "WARN", "Could not determine default branch from GitHub API")
    except Exception as exc:
        add("repo_default_branch", "WARN", f"Could not query default branch: {type(exc).__name__}")
else:
    add("repo_default_branch", "BLOCKER", "Cannot query default branch because token is missing")

symref = run(["bash", "-lc", f"timeout 20s git ls-remote --symref {ssh_url} HEAD"])
if symref.returncode == 0:
    branch = None
    for line in symref.stdout.splitlines():
        if line.startswith("ref:") and "HEAD" in line:
            branch = line.split()[1].replace("refs/heads/", "")
            break
    if branch:
        add("ssh_remote_head", "PASS", f"Remote HEAD branch via SSH: {branch}")
        if default_branch and branch != default_branch:
            add("ssh_head_mismatch", "WARN", f"SSH HEAD ({branch}) differs from API default branch ({default_branch})")
    else:
        add("ssh_remote_head", "WARN", "SSH remote HEAD could not be parsed")
else:
    add("ssh_remote_head", "BLOCKER", f"Failed to query remote HEAD via SSH: {ssh_url}")

heads = run(["bash", "-lc", f"timeout 20s git ls-remote --heads {ssh_url}"])
if heads.returncode == 0:
    count = len([ln for ln in heads.stdout.splitlines() if ln.strip()])
    add("ssh_pull_check", "PASS", f"SSH pull check passed ({count} remote heads visible)")
else:
    add("ssh_pull_check", "BLOCKER", f"SSH pull check failed for {ssh_url}")

summary = {"pass": 0, "warn": 0, "blocker": 0}
for item in checks:
    st = item["status"]
    if st == "PASS":
        summary["pass"] += 1
    elif st == "WARN":
        summary["warn"] += 1
    elif st == "BLOCKER":
        summary["blocker"] += 1

next_commands = []
if summary["blocker"] == 0:
    next_commands = [
        f"./scripts/clone-repo.sh --org {org} --repo {repo} --ssh-host {ssh_host} --https-fallback",
        f"./scripts/gen-pr-template.sh --base-version vX.Y.Z --change-type feat --ai-agent codex --ai-assistance medium",
    ]

if summary["blocker"] > 0:
    next_step = "Fix blockers, then rerun member-preflight.sh"
elif summary["warn"] > 0:
    next_step = "Address warnings when possible, then continue with clone-repo.sh"
else:
    next_step = "Environment ready for member workflow"

out = {
    "org": org,
    "repo": repo,
    "ssh_host": ssh_host,
    "summary": summary,
    "checks": checks,
    "next_step": next_step,
    "next_commands": next_commands,
    "onboarding_report": onboard_path,
}
Path(out_path).write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")

print("[member-preflight] Summary:")
print(f"- pass: {summary['pass']}")
print(f"- warn: {summary['warn']}")
print(f"- blocker: {summary['blocker']}")
for check in checks:
    print(f"[{check['status']}] {check['id']}: {check['message']}")
print(f"[member-preflight] next_step: {next_step}")
print(f"[member-preflight] report: {out_path}")
if next_commands:
    print("[member-preflight] suggested commands:")
    for cmd in next_commands:
        print(f"- {cmd}")

raise SystemExit(1 if summary["blocker"] > 0 else 0)
PY

rm -f "$TMP_ONBOARD_JSON"
