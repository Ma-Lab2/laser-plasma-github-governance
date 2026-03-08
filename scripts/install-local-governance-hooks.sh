#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-local-governance-hooks.sh

Installs local governance hooks in the current repository.
- If pre-commit is available, installs configured hooks via pre-commit.
- Otherwise installs equivalent fallback hooks directly into .git/hooks.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[ERROR] Current directory is not a git repository."
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ ! -x ".governance/check-commit-trailer.sh" || ! -f ".governance/validate-governance.py" ]]; then
  echo "[ERROR] Missing governance scripts under .governance/"
  exit 1
fi

if command -v pre-commit >/dev/null 2>&1; then
  pre-commit install
  pre-commit install --hook-type commit-msg
  echo "[OK] Installed hooks via pre-commit."
  exit 0
fi

hook_dir="$repo_root/.git/hooks"
mkdir -p "$hook_dir"

cat > "$hook_dir/pre-commit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec python3 ./.governance/validate-governance.py --mode local --required-skill-version 0.2.1
EOF

cat > "$hook_dir/commit-msg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec ./.governance/check-commit-trailer.sh "$1"
EOF

chmod +x "$hook_dir/pre-commit" "$hook_dir/commit-msg"
echo "[OK] pre-commit command not found. Installed fallback local hooks in .git/hooks."
