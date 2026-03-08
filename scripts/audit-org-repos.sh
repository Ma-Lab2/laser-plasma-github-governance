#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: audit-org-repos.sh --org <org> [--repo-list <file>] [--out <dir>] [--include-private]

Examples:
  audit-org-repos.sh --org Ma-Lab2
  audit-org-repos.sh --org Ma-Lab2 --repo-list repos.txt --out /tmp/ma-lab2-audit

Notes:
- --repo-list format: one repo per line (name only or full clone URL).
- Without --repo-list, script fetches public repos via GitHub API.
- include-private requires authenticated API setup outside this script.
EOF
}

ORG=""
REPO_LIST_FILE=""
OUT_DIR=""
INCLUDE_PRIVATE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)
      ORG="$2"
      shift 2
      ;;
    --repo-list)
      REPO_LIST_FILE="$2"
      shift 2
      ;;
    --out)
      OUT_DIR="$2"
      shift 2
      ;;
    --include-private)
      INCLUDE_PRIVATE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate-governance.py"

if [[ ! -x "$VALIDATOR" ]]; then
  echo "[ERROR] validator not executable: $VALIDATOR"
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="/tmp/${ORG,,}-governance-audit-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR/repos" "$OUT_DIR/results"

repos=()

if [[ -n "$REPO_LIST_FILE" ]]; then
  while IFS= read -r line; do
    line="${line#${line%%[![:space:]]*}}"
    line="${line%${line##*[![:space:]]}}"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    if [[ "$line" == https://* || "$line" == git@* ]]; then
      repos+=("$line")
    else
      repos+=("https://github.com/${ORG}/${line}.git")
    fi
  done < "$REPO_LIST_FILE"
else
  api_url="https://api.github.com/orgs/${ORG}/repos?per_page=100"
  if [[ "$INCLUDE_PRIVATE" == "true" ]]; then
    echo "[WARN] include-private requested, but no auth handling is built into this script."
    echo "[WARN] Continuing with public API view."
  fi
  mapfile -t repos < <(python3 - "$api_url" <<'PY'
import json
import sys
import urllib.request

url = sys.argv[1]
with urllib.request.urlopen(url, timeout=30) as resp:
    data = json.load(resp)

if not isinstance(data, list):
    raise SystemExit(f"API returned non-list payload: {data}")

for repo in data:
    print(repo["clone_url"])
PY
)
fi

if [[ ${#repos[@]} -eq 0 ]]; then
  echo "[ERROR] No repositories resolved for organization: $ORG"
  exit 1
fi

echo "[INFO] Resolved ${#repos[@]} repositories"

for clone_url in "${repos[@]}"; do
  repo_name="$(basename "$clone_url" .git)"
  repo_dir="$OUT_DIR/repos/$repo_name"
  json_out="$OUT_DIR/results/$repo_name.json"
  md_out="$OUT_DIR/results/$repo_name.md"

  echo "[INFO] Auditing $repo_name"
  if ! git clone --depth 1 "$clone_url" "$repo_dir" >/tmp/${repo_name}.clone.log 2>/tmp/${repo_name}.clone.err; then
    echo "[WARN] Clone failed for $clone_url"
    python3 - "$repo_name" "$clone_url" "$json_out" "$md_out" <<'PY'
import json
import sys
from pathlib import Path

repo_name, clone_url, json_out, md_out = sys.argv[1:]
payload = {
    "repo": repo_name,
    "mode": "audit",
    "installation": {
        "installed": False,
        "installed_version": None,
        "required_version": "0.2.1",
        "upgrade_required": None,
        "lock_valid": False,
        "validator_hash_ok": False,
        "template_hash_ok": False,
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
    f"# Governance Audit - {repo_name}\n\n- Mode: `audit`\n- Blockers: `1`\n- Warnings: `0`\n- Info: `0`\n\n| Severity | Code | Message |\n|---|---|---|\n| blocker | clone_failed | Failed to clone repository: {clone_url} |\n",
    encoding="utf-8",
)
PY
    continue
  fi

  (
    cd "$repo_dir"
    PYTHONDONTWRITEBYTECODE=1 "$VALIDATOR" --mode audit --output json --repo-name "$repo_name" --strict-placeholders true > "$json_out"
    PYTHONDONTWRITEBYTECODE=1 "$VALIDATOR" --mode audit --output md --repo-name "$repo_name" --strict-placeholders true > "$md_out"
  )
done

python3 - "$OUT_DIR" <<'PY'
import json
import sys
from pathlib import Path

out_dir = Path(sys.argv[1])
results_dir = out_dir / "results"
json_files = sorted(results_dir.glob("*.json"))

rows = []
for jf in json_files:
    payload = json.loads(jf.read_text(encoding="utf-8"))
    s = payload.get("summary", {})
    inst = payload.get("installation", {})
    rows.append(
        (
            payload.get("repo", jf.stem),
            s.get("blocker", 0),
            s.get("warning", 0),
            s.get("info", 0),
            inst.get("installed", False),
            inst.get("installed_version"),
            inst.get("required_version"),
            inst.get("upgrade_required"),
        )
    )

rows.sort(key=lambda x: (-x[1], -x[2], x[0].lower()))

lines = [
    f"# Governance Audit Summary - {out_dir.name}",
    "",
    "| Repository | Blockers | Warnings | Info | Skill Installed | Installed Version | Required Version | Upgrade Required |",
    "|---|---:|---:|---:|---|---|---|---|",
]
for repo, b, w, i, installed, installed_version, required_version, upgrade_required in rows:
    lines.append(
        f"| {repo} | {b} | {w} | {i} | {installed} | {installed_version} | {required_version} | {upgrade_required} |"
    )

summary = {
    "repositories": len(rows),
    "blocker_repos": sum(1 for _, b, *_ in rows if b > 0),
    "warning_repos": sum(1 for _, _, w, *_ in rows if w > 0),
    "installed_repos": sum(1 for _, _, _, _, installed, _, _, _ in rows if installed is True),
    "upgrade_required_repos": sum(1 for _, _, _, _, _, _, _, upgrade_required in rows if upgrade_required is True),
}

lines.extend([
    "",
    f"- Total repositories audited: `{summary['repositories']}`",
    f"- Repositories with blockers: `{summary['blocker_repos']}`",
    f"- Repositories with warnings: `{summary['warning_repos']}`",
    f"- Repositories with skill installed: `{summary['installed_repos']}`",
    f"- Repositories requiring skill upgrade: `{summary['upgrade_required_repos']}`",
])

(out_dir / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
(out_dir / "report.json").write_text(json.dumps({"summary": summary, "rows": rows}, ensure_ascii=False, indent=2), encoding="utf-8")

print(f"[OK] Wrote {out_dir / 'report.md'}")
print(f"[OK] Wrote {out_dir / 'report.json'}")
PY

echo "[OK] Audit complete: $OUT_DIR"
