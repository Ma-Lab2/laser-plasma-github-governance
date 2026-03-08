#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: commit-with-base.sh [options]

Options:
  --base-version <tag>      Required. e.g. v1.2.3
  --summary <text>          Required. Commit summary line
  --body <text>             Optional. Commit body paragraph
  --target-version <tag>    Optional. e.g. v1.2.4
  --allow-empty             Optional. Pass --allow-empty to git commit
  -h, --help                Show help

Example:
  commit-with-base.sh --base-version v1.2.3 --summary "fix: improve parser" --body "handles edge case"
USAGE
}

BASE_VERSION=""
SUMMARY=""
BODY=""
TARGET_VERSION=""
ALLOW_EMPTY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-version)
      BASE_VERSION="$2"
      shift 2
      ;;
    --summary)
      SUMMARY="$2"
      shift 2
      ;;
    --body)
      BODY="$2"
      shift 2
      ;;
    --target-version)
      TARGET_VERSION="$2"
      shift 2
      ;;
    --allow-empty)
      ALLOW_EMPTY="true"
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

if [[ -z "$BASE_VERSION" || -z "$SUMMARY" ]]; then
  echo "[ERROR] --base-version and --summary are required"
  usage
  exit 1
fi

if ! [[ "$BASE_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "[ERROR] --base-version must match vMAJOR.MINOR.PATCH"
  exit 1
fi

if [[ -n "$TARGET_VERSION" ]] && ! [[ "$TARGET_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "[ERROR] --target-version must match vMAJOR.MINOR.PATCH"
  exit 1
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "[ERROR] Current directory is not a git repository"
  exit 1
}

if [[ "$ALLOW_EMPTY" != "true" ]] && [[ -z "$(git status --porcelain)" ]]; then
  echo "[ERROR] No staged or unstaged changes detected. Use --allow-empty if intentional."
  exit 1
fi

cmd=(git commit -m "$SUMMARY")
if [[ -n "$BODY" ]]; then
  cmd+=(-m "$BODY")
fi
cmd+=(-m "Base-Version: $BASE_VERSION")
if [[ -n "$TARGET_VERSION" ]]; then
  cmd+=(-m "Target-Version: $TARGET_VERSION")
fi
if [[ "$ALLOW_EMPTY" == "true" ]]; then
  cmd+=(--allow-empty)
fi

"${cmd[@]}"

echo "[OK] Commit created with governance trailers."
