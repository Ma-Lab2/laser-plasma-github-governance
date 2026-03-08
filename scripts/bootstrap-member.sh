#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bootstrap-member.sh --repo <repo> [options]

Options:
  --org <org>              GitHub organization (default: Ma-Lab2)
  --repo <repo>            Repository name (required)
  --ssh-host <host>        SSH host alias in ~/.ssh/config (default: github.com)
  --token-env <ENV>        Token env var name (default: GH_TOKEN)
  --with-repo-list         Also print accessible repo list
  -h, --help               Show help

Example:
  bootstrap-member.sh --org Ma-Lab2 --repo Pytps-web --ssh-host github-small --with-repo-list
USAGE
}

ORG="Ma-Lab2"
REPO=""
SSH_HOST="github.com"
TOKEN_ENV="GH_TOKEN"
WITH_REPO_LIST="false"

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
    --with-repo-list)
      WITH_REPO_LIST="true"
      shift
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
HOOK_INSTALLER="$SCRIPT_DIR/install-local-governance-hooks.sh"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -x "$HOOK_INSTALLER" ]]; then
    echo "[INFO] Installing local governance hooks..."
    "$HOOK_INSTALLER"
  else
    echo "[WARN] Hook installer script not found: $HOOK_INSTALLER"
  fi
else
  echo "[WARN] Not inside a git repo; skipping local hook installation."
fi

echo "[INFO] Running member preflight..."
"$SCRIPT_DIR/member-preflight.sh" --org "$ORG" --repo "$REPO" --ssh-host "$SSH_HOST" --token-env "$TOKEN_ENV"

echo "[INFO] Recommended clone command:"
echo "  ./scripts/clone-repo.sh --org $ORG --repo $REPO --ssh-host $SSH_HOST --https-fallback"

if [[ "$WITH_REPO_LIST" == "true" ]]; then
  echo "[INFO] Listing accessible repositories..."
  "$SCRIPT_DIR/list-accessible-repos.sh" --org "$ORG" --ssh-host "$SSH_HOST" --token-env "$TOKEN_ENV"
fi

echo "[OK] Member bootstrap finished."
