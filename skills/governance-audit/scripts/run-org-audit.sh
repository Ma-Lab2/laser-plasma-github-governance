#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run-org-audit.sh --org <org> [options]

Options:
  --org <org>                         GitHub organization (required)
  --required-skill-version <x.y.z>   Required governance skill version (default: 0.2.1)
  --out <dir>                         Output directory
  --repo-list <file>                  Optional repository list file (one name or clone URL per line)
  --token-env <ENV>                   Token env var name (default: GH_TOKEN)
  --required-check <name>             Required status check (repeatable)
  --required-approvals <n>            Minimum required approving reviews (default: 1)
  --fail-on-blocker <true|false>      Return non-zero if any blocker found (default: true)
  --include-archived <true|false>     Include archived repos from org listing (default: false)
  -h, --help                          Show help

Examples:
  run-org-audit.sh --org Ma-Lab2
  run-org-audit.sh --org Ma-Lab2 --token-env MA_LAB2_AUDIT_TOKEN --fail-on-blocker false
EOF
}

ORG=""
REQUIRED_SKILL_VERSION="0.2.1"
OUT_DIR=""
REPO_LIST_FILE=""
TOKEN_ENV="GH_TOKEN"
FAIL_ON_BLOCKER="true"
INCLUDE_ARCHIVED="false"
REQUIRED_APPROVALS="1"
REQUIRED_CHECKS=(
  "governance/validate-pr-fields"
  "governance/validate-version"
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)
      ORG="$2"
      shift 2
      ;;
    --required-skill-version)
      REQUIRED_SKILL_VERSION="$2"
      shift 2
      ;;
    --out)
      OUT_DIR="$2"
      shift 2
      ;;
    --repo-list)
      REPO_LIST_FILE="$2"
      shift 2
      ;;
    --token-env)
      TOKEN_ENV="$2"
      shift 2
      ;;
    --required-check)
      REQUIRED_CHECKS+=("$2")
      shift 2
      ;;
    --required-approvals)
      REQUIRED_APPROVALS="$2"
      shift 2
      ;;
    --fail-on-blocker)
      FAIL_ON_BLOCKER="$2"
      shift 2
      ;;
    --include-archived)
      INCLUDE_ARCHIVED="$2"
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

if [[ -z "$ORG" ]]; then
  echo "[ERROR] --org is required"
  usage
  exit 1
fi

if [[ "$FAIL_ON_BLOCKER" != "true" && "$FAIL_ON_BLOCKER" != "false" ]]; then
  echo "[ERROR] --fail-on-blocker must be true|false"
  exit 1
fi

if [[ "$INCLUDE_ARCHIVED" != "true" && "$INCLUDE_ARCHIVED" != "false" ]]; then
  echo "[ERROR] --include-archived must be true|false"
  exit 1
fi

TOKEN="${!TOKEN_ENV:-}"
if [[ -z "$TOKEN" ]]; then
  if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="/tmp/${ORG,,}-governance-audit-$(date +%Y%m%d-%H%M%S)"
  fi
  mkdir -p "$OUT_DIR"
  python3 - "$ORG" "$TOKEN_ENV" "$OUT_DIR" <<'PY'
import json
import sys
from pathlib import Path

org, token_env, out_dir = sys.argv[1:]
msg = f"Missing required token env: {token_env}"
report_md = Path(out_dir) / "report.md"
report_json = Path(out_dir) / "report.json"
report_md.write_text(
    "\n".join(
        [
            f"# Governance Audit Summary - {Path(out_dir).name}",
            "",
            f"- Organization: `{org}`",
            "- Total repositories audited: `0`",
            "- Repositories with blockers: `1`",
            "",
            "| Scope | Severity | Code | Message |",
            "|---|---|---|---|",
            f"| organization | blocker | missing_token | {msg} |",
            "",
        ]
    ),
    encoding="utf-8",
)
report_json.write_text(
    json.dumps(
        {
            "summary": {
                "repositories": 0,
                "blocker_repos": 1,
                "warning_repos": 0,
                "installed_repos": 0,
                "upgrade_required_repos": 0,
                "platform_blocker_repos": 0,
                "content_blocker_repos": 0,
                "auth_ok": False,
            },
            "organization_findings": [{"severity": "blocker", "code": "missing_token", "message": msg}],
            "rows": [],
        },
        ensure_ascii=False,
        indent=2,
    ),
    encoding="utf-8",
)
print(f"[FAIL] {msg}")
print(f"[OK] Wrote {report_md}")
print(f"[OK] Wrote {report_json}")
PY
  exit 1
fi

AUTH_BASIC_HEADER="$(
  python3 - "$TOKEN" <<'PY'
import base64
import sys

token = sys.argv[1]
pair = f"x-access-token:{token}".encode("utf-8")
print("Authorization: Basic " + base64.b64encode(pair).decode("ascii"))
PY
)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GOV_REPO_ROOT="$(cd "$SKILL_ROOT/../.." && pwd)"
VALIDATOR="$GOV_REPO_ROOT/scripts/validate-governance.py"
PLATFORM_CHECKER="$SCRIPT_DIR/check-platform-policy.py"

if [[ ! -x "$VALIDATOR" ]]; then
  echo "[ERROR] validator not executable: $VALIDATOR"
  exit 1
fi

if [[ ! -f "$PLATFORM_CHECKER" ]]; then
  echo "[ERROR] missing platform checker: $PLATFORM_CHECKER"
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="/tmp/${ORG,,}-governance-audit-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR/repos" "$OUT_DIR/results" "$OUT_DIR/tmp"
REPO_TSV="$OUT_DIR/tmp/repositories.tsv"
: > "$REPO_TSV"

if [[ -n "$REPO_LIST_FILE" ]]; then
  while IFS= read -r line; do
    line="${line#${line%%[![:space:]]*}}"
    line="${line%${line##*[![:space:]]}}"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    if [[ "$line" == https://* || "$line" == git@* ]]; then
      repo_name="$(basename "$line" .git)"
      printf '%s\t%s\n' "$repo_name" "$line" >> "$REPO_TSV"
    else
      printf '%s\t%s\n' "$line" "https://github.com/${ORG}/${line}.git" >> "$REPO_TSV"
    fi
  done < "$REPO_LIST_FILE"
else
  if ! python3 - "$ORG" "$INCLUDE_ARCHIVED" "$REPO_TSV" "$TOKEN" <<'PY'
import json
import sys
import urllib.parse
import urllib.request
import urllib.error

org, include_archived, output_path, token = sys.argv[1:]
include_archived = include_archived.lower() == "true"
page = 1
rows = []

while True:
    url = f"https://api.github.com/orgs/{urllib.parse.quote(org)}/repos?per_page=100&page={page}&type=all"
    req = urllib.request.Request(
        url=url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "governance-audit-skill",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            msg = json.loads(body).get("message", body)
        except json.JSONDecodeError:
            msg = body or str(exc)
        raise SystemExit(f"Failed to list repositories for org {org}: {msg}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"Failed to list repositories for org {org}: {exc}") from exc
    if not isinstance(payload, list):
        msg = payload.get("message", "non-list response")
        raise SystemExit(f"Failed to list repositories for org {org}: {msg}")
    if not payload:
        break
    for repo in payload:
        if repo.get("disabled"):
            continue
        if not include_archived and repo.get("archived"):
            continue
        rows.append((repo["name"], repo["clone_url"]))
    page += 1

with open(output_path, "w", encoding="utf-8") as f:
    for name, clone_url in rows:
        f.write(f"{name}\t{clone_url}\n")
PY
  then
    python3 - "$ORG" "$OUT_DIR" <<'PY'
import json
import sys
from pathlib import Path

org, out_dir = sys.argv[1:]
msg = "Failed to list organization repositories via GitHub API (check token scope and validity)"
report_md = Path(out_dir) / "report.md"
report_json = Path(out_dir) / "report.json"
report_md.write_text(
    "\n".join(
        [
            f"# Governance Audit Summary - {Path(out_dir).name}",
            "",
            f"- Organization: `{org}`",
            "- Total repositories audited: `0`",
            "- Repositories with blockers: `1`",
            "",
            "| Scope | Severity | Code | Message |",
            "|---|---|---|---|",
            f"| organization | blocker | org_repo_list_failed | {msg} |",
            "",
        ]
    ),
    encoding="utf-8",
)
report_json.write_text(
    json.dumps(
        {
            "summary": {
                "repositories": 0,
                "blocker_repos": 1,
                "warning_repos": 0,
                "installed_repos": 0,
                "upgrade_required_repos": 0,
                "platform_blocker_repos": 0,
                "content_blocker_repos": 0,
                "auth_ok": False,
            },
            "organization_findings": [{"severity": "blocker", "code": "org_repo_list_failed", "message": msg}],
            "rows": [],
        },
        ensure_ascii=False,
        indent=2,
    ),
    encoding="utf-8",
)
print(f"[FAIL] {msg}")
print(f"[OK] Wrote {report_md}")
print(f"[OK] Wrote {report_json}")
PY
    exit 1
  fi
fi

if [[ ! -s "$REPO_TSV" ]]; then
  echo "[ERROR] No repositories resolved for organization: $ORG"
  exit 1
fi

repo_count="$(wc -l < "$REPO_TSV" | tr -d ' ')"
echo "[INFO] Resolved ${repo_count} repositories"

check_args=()
for c in "${REQUIRED_CHECKS[@]}"; do
  check_args+=(--required-check "$c")
done

while IFS=$'\t' read -r repo_name clone_url; do
  [[ -z "$repo_name" ]] && continue
  repo_dir="$OUT_DIR/repos/$repo_name"
  content_json="$OUT_DIR/results/$repo_name.content.json"
  platform_json="$OUT_DIR/results/$repo_name.platform.json"
  combined_json="$OUT_DIR/results/$repo_name.json"
  combined_md="$OUT_DIR/results/$repo_name.md"

  echo "[INFO] Auditing $repo_name"

  rm -rf "$repo_dir"
  clone_ok="true"
  if [[ "$clone_url" == git@* ]]; then
    if ! GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never \
      git \
      -c credential.helper= \
      -c credential.interactive=never \
      -c core.askPass= \
      clone --depth 1 "$clone_url" "$repo_dir" >"$OUT_DIR/tmp/$repo_name.clone.log" 2>"$OUT_DIR/tmp/$repo_name.clone.err"; then
      clone_ok="false"
    fi
  else
    if ! GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never \
      git \
      -c credential.helper= \
      -c credential.interactive=never \
      -c core.askPass= \
      -c "http.extraHeader=$AUTH_BASIC_HEADER" \
      clone --depth 1 "$clone_url" "$repo_dir" >"$OUT_DIR/tmp/$repo_name.clone.log" 2>"$OUT_DIR/tmp/$repo_name.clone.err"; then
      clone_ok="false"
    fi
  fi

  if [[ "$clone_ok" != "true" ]]; then
    python3 - "$repo_name" "$clone_url" "$REQUIRED_SKILL_VERSION" "$combined_json" "$combined_md" <<'PY'
import json
import sys
from pathlib import Path

repo_name, clone_url, required_version, json_out, md_out = sys.argv[1:]
payload = {
    "repo": repo_name,
    "mode": "audit",
    "installation": {
        "installed": False,
        "installed_version": None,
        "required_version": required_version,
        "upgrade_required": None,
        "lock_valid": False,
        "validator_hash_ok": False,
        "template_hash_ok": False,
    },
    "platform": {
        "default_branch": None,
        "branch_protection": {"enabled": False},
        "required_checks": {"required": [], "configured": [], "missing": []},
        "required_reviews": {"required": 1, "current": 0},
    },
    "summary": {"blocker": 1, "warning": 0, "info": 0},
    "findings": [
        {
            "severity": "blocker",
            "code": "clone_failed",
            "message": f"Failed to clone repository: {clone_url}",
        }
    ],
}
Path(json_out).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
Path(md_out).write_text(
    "\n".join(
        [
            f"# Governance Audit - {repo_name}",
            "",
            "- Mode: `audit`",
            "- Blockers: `1`",
            "- Warnings: `0`",
            "- Info: `0`",
            "",
            "| Severity | Code | Message |",
            "|---|---|---|",
            f"| blocker | clone_failed | Failed to clone repository: {clone_url} |",
            "",
        ]
    ),
    encoding="utf-8",
)
PY
    continue
  fi

  if ! (
    cd "$repo_dir"
    PYTHONDONTWRITEBYTECODE=1 "$VALIDATOR" \
      --mode audit \
      --output json \
      --repo-name "$repo_name" \
      --strict-placeholders true \
      --required-skill-version "$REQUIRED_SKILL_VERSION" > "$content_json"
  ); then
    python3 - "$repo_name" "$content_json" "$REQUIRED_SKILL_VERSION" <<'PY'
import json
import sys
from pathlib import Path

repo_name, content_json, required_version = sys.argv[1:]
payload = {
    "repo": repo_name,
    "mode": "audit",
    "installation": {
        "installed": False,
        "installed_version": None,
        "required_version": required_version,
        "upgrade_required": None,
        "lock_valid": False,
        "validator_hash_ok": False,
        "template_hash_ok": False,
    },
    "summary": {"blocker": 1, "warning": 0, "info": 0},
    "findings": [
        {
            "severity": "blocker",
            "code": "content_validator_failed",
            "message": "validate-governance.py execution failed",
        }
    ],
}
Path(content_json).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
PY
  fi

  if ! python3 "$PLATFORM_CHECKER" \
    --org "$ORG" \
    --repo "$repo_name" \
    --token-env "$TOKEN_ENV" \
    --required-approvals "$REQUIRED_APPROVALS" \
    "${check_args[@]}" \
    --output json > "$platform_json"; then
    python3 - "$repo_name" "$REQUIRED_APPROVALS" "$platform_json" <<'PY'
import json
import sys
from pathlib import Path

repo_name, required_approvals, output_path = sys.argv[1:]
payload = {
    "repo": repo_name,
    "platform": {
        "default_branch": None,
        "branch_protection": {"enabled": False},
        "required_checks": {"required": [], "configured": [], "missing": []},
        "required_reviews": {"required": int(required_approvals), "current": 0},
    },
    "summary": {"blocker": 1, "warning": 0, "info": 0},
    "findings": [
        {
            "severity": "blocker",
            "code": "platform_check_failed",
            "message": "Platform policy checker execution failed",
        }
    ],
}
Path(output_path).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
PY
  fi

  python3 - "$repo_name" "$content_json" "$platform_json" "$combined_json" "$combined_md" <<'PY'
import json
import sys
from pathlib import Path

repo_name, content_json, platform_json, combined_json, combined_md = sys.argv[1:]
content = json.loads(Path(content_json).read_text(encoding="utf-8"))
platform = json.loads(Path(platform_json).read_text(encoding="utf-8"))

findings = list(content.get("findings", [])) + list(platform.get("findings", []))
summary = {"blocker": 0, "warning": 0, "info": 0}
for finding in findings:
    sev = finding.get("severity")
    if sev in summary:
        summary[sev] += 1

payload = {
    "repo": repo_name,
    "mode": "audit",
    "installation": content.get("installation", {}),
    "platform": platform.get("platform", {}),
    "summary": summary,
    "findings": findings,
}
Path(combined_json).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

platform_data = payload.get("platform", {})
bp_enabled = (platform_data.get("branch_protection") or {}).get("enabled")
missing_checks = (platform_data.get("required_checks") or {}).get("missing") or []
required_reviews = (platform_data.get("required_reviews") or {}).get("required")
current_reviews = (platform_data.get("required_reviews") or {}).get("current")

lines = [
    f"# Governance Audit - {repo_name}",
    "",
    "- Mode: `audit`",
    f"- Blockers: `{summary['blocker']}`",
    f"- Warnings: `{summary['warning']}`",
    f"- Info: `{summary['info']}`",
    f"- Skill installed: `{payload.get('installation', {}).get('installed')}`",
    f"- Installed version: `{payload.get('installation', {}).get('installed_version')}`",
    f"- Required version: `{payload.get('installation', {}).get('required_version')}`",
    f"- Branch protection enabled: `{bp_enabled}`",
    f"- Missing required checks: `{', '.join(missing_checks) if missing_checks else 'none'}`",
    f"- Required approvals: `{current_reviews}` / `{required_reviews}`",
    "",
]

if findings:
    lines.extend(["| Severity | Code | Message |", "|---|---|---|"])
    for finding in findings:
        msg = str(finding.get("message", "")).replace("|", "\\|")
        lines.append(f"| {finding.get('severity')} | {finding.get('code')} | {msg} |")
else:
    lines.append("No findings.")

lines.append("")
Path(combined_md).write_text("\n".join(lines), encoding="utf-8")
PY
done < "$REPO_TSV"

python3 - "$OUT_DIR" <<'PY'
import json
import sys
from pathlib import Path

out_dir = Path(sys.argv[1])
results_dir = out_dir / "results"
json_files = sorted(p for p in results_dir.glob("*.json") if ".content." not in p.name and ".platform." not in p.name)

rows = []
summary = {
    "repositories": 0,
    "blocker_repos": 0,
    "warning_repos": 0,
    "installed_repos": 0,
    "upgrade_required_repos": 0,
    "platform_blocker_repos": 0,
    "content_blocker_repos": 0,
    "auth_ok": True,
}

for jf in json_files:
    payload = json.loads(jf.read_text(encoding="utf-8"))
    repo = payload.get("repo", jf.stem)
    s = payload.get("summary", {})
    inst = payload.get("installation", {})
    findings = payload.get("findings", [])
    platform_findings = [f for f in findings if str(f.get("code", "")).startswith(("missing_required_checks", "insufficient_required_reviews", "branch_protection", "repo_api", "platform_check", "missing_token", "branch_protection_unreadable"))]
    content_findings = [f for f in findings if f not in platform_findings]
    platform = payload.get("platform", {})
    missing_checks = (platform.get("required_checks") or {}).get("missing") or []
    rows.append(
        {
            "repo": repo,
            "blocker": int(s.get("blocker", 0)),
            "warning": int(s.get("warning", 0)),
            "info": int(s.get("info", 0)),
            "installed": inst.get("installed"),
            "installed_version": inst.get("installed_version"),
            "required_version": inst.get("required_version"),
            "upgrade_required": inst.get("upgrade_required"),
            "branch_protection": (platform.get("branch_protection") or {}).get("enabled"),
            "missing_checks": missing_checks,
            "platform_blockers": sum(1 for f in platform_findings if f.get("severity") == "blocker"),
            "content_blockers": sum(1 for f in content_findings if f.get("severity") == "blocker"),
        }
    )

summary["repositories"] = len(rows)
summary["blocker_repos"] = sum(1 for r in rows if r["blocker"] > 0)
summary["warning_repos"] = sum(1 for r in rows if r["warning"] > 0)
summary["installed_repos"] = sum(1 for r in rows if r["installed"] is True)
summary["upgrade_required_repos"] = sum(1 for r in rows if r["upgrade_required"] is True)
summary["platform_blocker_repos"] = sum(1 for r in rows if r["platform_blockers"] > 0)
summary["content_blocker_repos"] = sum(1 for r in rows if r["content_blockers"] > 0)

rows_sorted = sorted(rows, key=lambda r: (-r["blocker"], -r["warning"], r["repo"].lower()))

lines = [
    f"# Governance Audit Summary - {out_dir.name}",
    "",
    "| Repository | Blockers | Warnings | Info | Skill Installed | Installed Version | Required Version | Upgrade Required | Branch Protection | Missing Checks |",
    "|---|---:|---:|---:|---|---|---|---|---|---|",
]
for row in rows_sorted:
    lines.append(
        "| {repo} | {blocker} | {warning} | {info} | {installed} | {installed_version} | {required_version} | {upgrade_required} | {branch_protection} | {missing_checks} |".format(
            repo=row["repo"],
            blocker=row["blocker"],
            warning=row["warning"],
            info=row["info"],
            installed=row["installed"],
            installed_version=row["installed_version"],
            required_version=row["required_version"],
            upgrade_required=row["upgrade_required"],
            branch_protection=row["branch_protection"],
            missing_checks=", ".join(row["missing_checks"]) if row["missing_checks"] else "none",
        )
    )

lines.extend(
    [
        "",
        f"- Total repositories audited: `{summary['repositories']}`",
        f"- Repositories with blockers: `{summary['blocker_repos']}`",
        f"- Repositories with warnings: `{summary['warning_repos']}`",
        f"- Repositories with skill installed: `{summary['installed_repos']}`",
        f"- Repositories requiring skill upgrade: `{summary['upgrade_required_repos']}`",
        f"- Repositories with platform blockers: `{summary['platform_blocker_repos']}`",
        f"- Repositories with content blockers: `{summary['content_blocker_repos']}`",
    ]
)

(out_dir / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
(out_dir / "report.json").write_text(
    json.dumps({"summary": summary, "rows": rows_sorted}, ensure_ascii=False, indent=2),
    encoding="utf-8",
)

print(f"[OK] Wrote {out_dir / 'report.md'}")
print(f"[OK] Wrote {out_dir / 'report.json'}")
PY

echo "[OK] Audit complete: $OUT_DIR"

if [[ "$FAIL_ON_BLOCKER" == "true" ]]; then
  blocker_repos="$(python3 - "$OUT_DIR/report.json" <<'PY'
import json
import sys
from pathlib import Path
payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(payload.get("summary", {}).get("blocker_repos", 0))
PY
)"
  if [[ "$blocker_repos" -gt 0 ]]; then
    echo "[FAIL] Blockers found in ${blocker_repos} repositories"
    exit 1
  fi
fi

exit 0
