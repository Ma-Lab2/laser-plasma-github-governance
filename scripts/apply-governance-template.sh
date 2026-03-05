#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: apply-governance-template.sh <target-repo-path> [skill-version]

Example:
  apply-governance-template.sh /path/to/repo 0.2.0
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

TARGET="$(cd "$1" && pwd)"
SKILL_VERSION="${2:-0.2.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_ROOT/assets/repo-template"

if [[ ! -d "$TARGET/.git" ]]; then
  echo "[ERROR] Target is not a git repository: $TARGET"
  exit 1
fi

cp -a "$TEMPLATE"/. "$TARGET"/
python3 "$REPO_ROOT/scripts/update-skill-lock.py" \
  --repo-root "$TARGET" \
  --skill-version "$SKILL_VERSION" \
  --skill-repo "https://github.com/Ma-Lab2/laser-plasma-github-governance.git"

echo "[OK] Governance template applied to: $TARGET"
