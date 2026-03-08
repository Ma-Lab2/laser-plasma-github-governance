#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: gen-pr-template.sh [options]

Options:
  --base-version <tag>      Required. e.g. v1.2.3
  --change-type <type>      Required. feat|fix|chore|docs|refactor|release|experiment
  --target-version <tag>    Optional. e.g. v1.2.4 (or N/A)
  --ai-agent <name>         Optional. codex|claude-code|cursor|copilot|other|none (default: none)
  --ai-assistance <level>   Optional. none|low|medium|high (default: none)
  --ai-notes <text>         Optional. default: N/A
  --output <path>           Optional. Write to file instead of stdout
  -h, --help                Show help

Example:
  gen-pr-template.sh --base-version v0.2.1 --change-type feat --ai-agent codex --ai-assistance medium
USAGE
}

BASE_VERSION=""
CHANGE_TYPE=""
TARGET_VERSION="N/A"
AI_AGENT="none"
AI_ASSISTANCE="none"
AI_NOTES="N/A"
OUTPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-version)
      BASE_VERSION="$2"
      shift 2
      ;;
    --change-type)
      CHANGE_TYPE="$2"
      shift 2
      ;;
    --target-version)
      TARGET_VERSION="$2"
      shift 2
      ;;
    --ai-agent)
      AI_AGENT="$2"
      shift 2
      ;;
    --ai-assistance)
      AI_ASSISTANCE="$2"
      shift 2
      ;;
    --ai-notes)
      AI_NOTES="$2"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="$2"
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

if [[ -z "$BASE_VERSION" || -z "$CHANGE_TYPE" ]]; then
  echo "[ERROR] --base-version and --change-type are required"
  usage
  exit 1
fi

if ! [[ "$BASE_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "[ERROR] --base-version must match vMAJOR.MINOR.PATCH"
  exit 1
fi

if [[ "$TARGET_VERSION" != "N/A" ]] && ! [[ "$TARGET_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "[ERROR] --target-version must be N/A or vMAJOR.MINOR.PATCH"
  exit 1
fi

case "$CHANGE_TYPE" in
  feat|fix|chore|docs|refactor|release|experiment) ;;
  *)
    echo "[ERROR] --change-type must be one of: feat, fix, chore, docs, refactor, release, experiment"
    exit 1
    ;;
esac

case "$AI_AGENT" in
  codex|claude-code|cursor|copilot|other|none) ;;
  *)
    echo "[ERROR] --ai-agent must be one of: codex, claude-code, cursor, copilot, other, none"
    exit 1
    ;;
esac

case "$AI_ASSISTANCE" in
  none|low|medium|high) ;;
  *)
    echo "[ERROR] --ai-assistance must be one of: none, low, medium, high"
    exit 1
    ;;
esac

body="$(cat <<TPL
## Summary
- [TODO] What changed and why.

## Validation
- [ ] Local checks passed
- [ ] CI checks passed

## Governance Fields
- Base-Version: $BASE_VERSION
- Change-Type: $CHANGE_TYPE
- Target-Version: $TARGET_VERSION
- AI-Agent: $AI_AGENT
- AI-Assistance: $AI_ASSISTANCE
- Human-Review-Confirmed: yes
- AI-Notes: $AI_NOTES
TPL
)"

if [[ -n "$OUTPUT_PATH" ]]; then
  printf '%s\n' "$body" > "$OUTPUT_PATH"
  echo "[OK] Wrote PR template to: $OUTPUT_PATH"
else
  printf '%s\n' "$body"
fi
