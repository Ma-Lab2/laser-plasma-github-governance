#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: clone-repo.sh --org <org> --repo <repo> [options]

Options:
  --ssh-host <host>        SSH host alias in ~/.ssh/config (default: github.com)
  --dest <dir>             Destination parent directory (default: current directory)
  --branch <branch>        Branch to clone (default: auto-detect default branch)
  --timeout <seconds>      Timeout per git operation (default: 90)
  --verify                 Verify cloned repo health (default: true)
  --no-verify              Skip cloned repo health verification
  --https-fallback         Fallback to HTTPS clone if SSH clone times out/fails
  --keep-https-remote      Keep HTTPS as origin when fallback succeeds
  -h, --help               Show help

Examples:
  clone-repo.sh --org Ma-Lab2 --repo Pytps-web --ssh-host github-small --https-fallback
  clone-repo.sh --org Ma-Lab2 --repo demo-repository --dest "/mnt/d/software/Github projects"
EOF
}

ORG=""
REPO=""
SSH_HOST="github.com"
DEST_DIR="$(pwd)"
BRANCH=""
TIMEOUT_SECS="90"
HTTPS_FALLBACK="false"
KEEP_HTTPS_REMOTE="false"
VERIFY_CLONE="true"

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
    --dest)
      DEST_DIR="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECS="$2"
      shift 2
      ;;
    --verify)
      VERIFY_CLONE="true"
      shift
      ;;
    --no-verify)
      VERIFY_CLONE="false"
      shift
      ;;
    --https-fallback)
      HTTPS_FALLBACK="true"
      shift
      ;;
    --keep-https-remote)
      KEEP_HTTPS_REMOTE="true"
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

if [[ -z "$ORG" || -z "$REPO" ]]; then
  echo "[ERROR] --org and --repo are required"
  usage
  exit 1
fi

if ! [[ "$TIMEOUT_SECS" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] --timeout must be an integer (seconds)"
  exit 1
fi

mkdir -p "$DEST_DIR"
TARGET_DIR="$DEST_DIR/$REPO"

if [[ -e "$TARGET_DIR" ]]; then
  echo "[ERROR] Destination already exists: $TARGET_DIR"
  exit 1
fi

SSH_URL="git@$SSH_HOST:$ORG/$REPO.git"
HTTPS_URL="https://github.com/$ORG/$REPO.git"

if [[ -z "$BRANCH" ]]; then
  echo "[INFO] Detecting default branch from remote..."
  HEAD_REF="$(timeout "$TIMEOUT_SECS" git ls-remote --symref "$SSH_URL" HEAD 2>/dev/null | awk '/^ref:/ {print $2}' | sed 's#refs/heads/##' || true)"
  if [[ -z "$HEAD_REF" ]]; then
    HEAD_REF="$(timeout "$TIMEOUT_SECS" git ls-remote --symref "$HTTPS_URL" HEAD 2>/dev/null | awk '/^ref:/ {print $2}' | sed 's#refs/heads/##' || true)"
  fi
  BRANCH="${HEAD_REF:-main}"
fi

echo "[INFO] Cloning $ORG/$REPO (branch: $BRANCH)"
echo "[INFO] SSH URL: $SSH_URL"

clone_ok="false"
if timeout "$TIMEOUT_SECS" git clone --branch "$BRANCH" --single-branch "$SSH_URL" "$TARGET_DIR"; then
  clone_ok="true"
else
  echo "[WARN] SSH clone failed or timed out."
fi

if [[ "$clone_ok" != "true" && "$HTTPS_FALLBACK" == "true" ]]; then
  echo "[INFO] Retrying clone with HTTPS fallback..."
  timeout "$TIMEOUT_SECS" git clone --branch "$BRANCH" --single-branch "$HTTPS_URL" "$TARGET_DIR"
  if [[ "$KEEP_HTTPS_REMOTE" != "true" ]]; then
    git -C "$TARGET_DIR" remote set-url origin "$SSH_URL"
    echo "[INFO] origin switched back to SSH URL after HTTPS fallback."
  fi
  clone_ok="true"
fi

if [[ "$clone_ok" != "true" ]]; then
  echo "[ERROR] Clone failed. You can run scripts/cleanup-git-hang.sh and retry."
  exit 1
fi

if [[ "$VERIFY_CLONE" == "true" ]]; then
  verify_failed="false"

  if ! git -C "$TARGET_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "[ERROR] Clone verification failed: local HEAD is missing."
    verify_failed="true"
  fi

  status_line="$(git -C "$TARGET_DIR" status --short --branch 2>/dev/null | head -n 1 || true)"
  if [[ -z "$status_line" || "$status_line" == "## No commits yet on "* ]]; then
    echo "[ERROR] Clone verification failed: repository has no usable checked-out branch."
    verify_failed="true"
  fi

  origin_url="$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || true)"
  expected_ssh_prefix="git@$SSH_HOST:$ORG/$REPO.git"
  if [[ "$KEEP_HTTPS_REMOTE" != "true" && "$origin_url" != "$expected_ssh_prefix" ]]; then
    echo "[ERROR] Clone verification failed: origin mismatch."
    echo "        Expected: $expected_ssh_prefix"
    echo "        Actual:   $origin_url"
    verify_failed="true"
  fi

  if [[ "$verify_failed" == "true" ]]; then
    echo "[ERROR] Clone verification failed. Suggested recovery:"
    echo "        1) ./scripts/cleanup-git-hang.sh --repo $ORG/$REPO"
    echo "        2) retry clone with --https-fallback"
    exit 1
  fi

  echo "[OK] Clone verification passed."
fi

echo "[OK] Clone complete: $TARGET_DIR"
git -C "$TARGET_DIR" status --short --branch
echo "[INFO] Latest commit:"
git -C "$TARGET_DIR" log -1 --pretty=format:'%h %s'
echo
echo "[INFO] origin remotes:"
git -C "$TARGET_DIR" remote -v
