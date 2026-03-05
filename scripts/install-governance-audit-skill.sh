#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/skills/governance-audit"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
DEST_DIR="$CODEX_HOME_DIR/skills/governance-audit"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "[ERROR] Source skill directory not found: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$(dirname "$DEST_DIR")"
rm -rf "$DEST_DIR"
cp -a "$SOURCE_DIR" "$DEST_DIR"

VALIDATOR="$CODEX_HOME_DIR/skills/.system/skill-creator/scripts/quick_validate.py"
if [[ -f "$VALIDATOR" ]]; then
  python3 "$VALIDATOR" "$DEST_DIR"
else
  echo "[WARN] quick validator not found: $VALIDATOR"
fi

echo "[OK] Installed governance audit skill to: $DEST_DIR"
