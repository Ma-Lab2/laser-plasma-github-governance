#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cleanup-git-hang.sh [--repo <org/repo>] [--dry-run]

Examples:
  cleanup-git-hang.sh
  cleanup-git-hang.sh --repo Ma-Lab2/Pytps-web
  cleanup-git-hang.sh --repo Ma-Lab2/Pytps-web --dry-run
EOF
}

repo_filter=""
dry_run="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo_filter="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
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

pattern="git-upload-pack|git clone|git fetch|git ls-remote"
if [[ -n "$repo_filter" ]]; then
  pattern="$pattern|$repo_filter|git@$repo_filter"
fi

mapfile -t lines < <(ps -eo pid=,ppid=,cmd= | grep -E "$pattern" | grep -vE "grep -E|cleanup-git-hang.sh" || true)

if [[ ${#lines[@]} -eq 0 ]]; then
  echo "[OK] No hanging git/ssh processes found."
  exit 0
fi

echo "[INFO] Candidate processes:"
for line in "${lines[@]}"; do
  echo "  $line"
done

if [[ "$dry_run" == "true" ]]; then
  echo "[OK] Dry run complete. No process killed."
  exit 0
fi

killed=0
for line in "${lines[@]}"; do
  pid="$(awk '{print $1}' <<<"$line")"
  if kill "$pid" 2>/dev/null; then
    killed=$((killed + 1))
  fi
done

sleep 1
echo "[INFO] Killed process count: $killed"

mapfile -t remain < <(ps -eo pid=,ppid=,cmd= | grep -E "$pattern" | grep -vE "grep -E|cleanup-git-hang.sh" || true)
if [[ ${#remain[@]} -eq 0 ]]; then
  echo "[OK] Cleanup successful. No matching process remains."
  exit 0
fi

echo "[WARN] Some matching processes are still running:"
for line in "${remain[@]}"; do
  echo "  $line"
done
exit 1
