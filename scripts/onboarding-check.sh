#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: onboarding-check.sh [options]

Options:
  --org <org>              GitHub organization (default: Ma-Lab2)
  --repo <repo>            Repository name for optional access check
  --token-env <ENV>        Token env var name (default: GH_TOKEN)
  --out <path>             JSON output path (default: ./onboarding-check.json)
  -h, --help               Show help

Example:
  ./scripts/onboarding-check.sh --org Ma-Lab2 --repo laser-plasma-github-governance
EOF
}

ORG="Ma-Lab2"
REPO=""
TOKEN_ENV="GH_TOKEN"
OUT_JSON="./onboarding-check.json"

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOKEN="${!TOKEN_ENV:-}"

TMP_JSON="$(mktemp)"

python3 - "$TMP_JSON" "$ORG" "$REPO" "$TOKEN_ENV" "$TOKEN" "$REPO_ROOT" <<'PY'
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

out_path, org, repo, token_env, token, repo_root = sys.argv[1:]
checks = []

def add(check_id: str, status: str, message: str) -> None:
    checks.append({"id": check_id, "status": status, "message": message})

def gh_get(url: str, token_value: str):
    req = urllib.request.Request(
        url=url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token_value}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "onboarding-check",
        },
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))

# 1) Basic command availability
for cmd in ("git", "python3"):
    proc = subprocess.run(["bash", "-lc", f"command -v {cmd} >/dev/null 2>&1"], capture_output=True)
    if proc.returncode == 0:
        add(f"cmd_{cmd}", "PASS", f"Command available: {cmd}")
    else:
        add(f"cmd_{cmd}", "BLOCKER", f"Missing required command: {cmd}")

# 2) Token existence
if token:
    add("token_exists", "PASS", f"Environment variable {token_env} is set")
else:
    add("token_exists", "BLOCKER", f"Environment variable {token_env} is missing")

# 3) Org API access
if token:
    try:
        gh_get(f"https://api.github.com/orgs/{urllib.parse.quote(org)}", token)
        add("org_access", "PASS", f"Can access organization: {org}")
    except urllib.error.HTTPError as exc:
        add("org_access", "BLOCKER", f"Cannot access org {org}: HTTP {exc.code}")
    except Exception as exc:
        add("org_access", "BLOCKER", f"Cannot access org {org}: {type(exc).__name__}")
else:
    add("org_access", "BLOCKER", "Skipped org check because token is missing")

# 4) Optional repository access
if repo:
    if token:
        try:
            gh_get(
                f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}",
                token,
            )
            add("repo_access", "PASS", f"Can access repository: {org}/{repo}")
        except urllib.error.HTTPError as exc:
            add("repo_access", "BLOCKER", f"Cannot access repository {org}/{repo}: HTTP {exc.code}")
        except Exception as exc:
            add("repo_access", "BLOCKER", f"Cannot access repository {org}/{repo}: {type(exc).__name__}")
    else:
        add("repo_access", "BLOCKER", "Skipped repository check because token is missing")

# 5) Git repository context
proc = subprocess.run(
    ["git", "-C", repo_root, "rev-parse", "--is-inside-work-tree"],
    text=True,
    capture_output=True,
)
if proc.returncode == 0 and proc.stdout.strip() == "true":
    add("repo_context", "PASS", f"Valid git repository: {repo_root}")
else:
    add("repo_context", "BLOCKER", f"Not a valid git repository: {repo_root}")

# 6) Required script existence
required_paths = [
    Path(repo_root) / "scripts" / "apply-governance-template.sh",
    Path(repo_root) / "skills" / "governance-audit" / "scripts" / "run-org-audit.sh",
]
missing = [p for p in required_paths if not p.exists()]
if missing:
    add("required_scripts", "BLOCKER", "Missing required scripts: " + ", ".join(str(p) for p in missing))
else:
    add("required_scripts", "PASS", "Required governance scripts are present")

# 7) Credential manager interaction risk
helper_values = []
for scope in ("--global", "--system"):
    proc = subprocess.run(["git", "config", scope, "--get", "credential.helper"], text=True, capture_output=True)
    if proc.returncode == 0 and proc.stdout.strip():
        helper_values.append(proc.stdout.strip())

if any("credential-manager" in h or "manager-core" in h for h in helper_values):
    add("credential_interactive_risk", "WARN", "Credential manager detected; keep non-interactive flags for scripts")
else:
    add("credential_interactive_risk", "PASS", "No interactive credential manager risk detected")

summary = {"pass": 0, "warn": 0, "blocker": 0}
for item in checks:
    status = item["status"]
    if status == "PASS":
        summary["pass"] += 1
    elif status == "WARN":
        summary["warn"] += 1
    elif status == "BLOCKER":
        summary["blocker"] += 1

if summary["blocker"] > 0:
    next_step = "Fix blockers first, then rerun onboarding-check.sh"
elif summary["warn"] > 0:
    next_step = "Address warnings when possible, then start member/admin path"
else:
    next_step = "Environment ready. Continue with onboarding docs"

payload = {
    "org": org,
    "repo": repo or None,
    "token_env": token_env,
    "checks": checks,
    "summary": summary,
    "next_step": next_step,
}

Path(out_path).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
PY

mkdir -p "$(dirname "$OUT_JSON")"
cp "$TMP_JSON" "$OUT_JSON"

python3 - "$OUT_JSON" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
summary = payload["summary"]
print("[onboarding-check] Summary:")
print(f"- pass: {summary['pass']}")
print(f"- warn: {summary['warn']}")
print(f"- blocker: {summary['blocker']}")
for check in payload["checks"]:
    print(f"[{check['status']}] {check['id']}: {check['message']}")
print(f"[onboarding-check] next_step: {payload['next_step']}")
print(f"[onboarding-check] report: {path}")
PY

rm -f "$TMP_JSON"

if python3 - "$OUT_JSON" <<'PY'
import json
import sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
raise SystemExit(1 if data["summary"]["blocker"] > 0 else 0)
PY
then
  exit 0
else
  exit 1
fi
