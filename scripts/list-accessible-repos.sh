#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: list-accessible-repos.sh [options]

Options:
  --org <org>              GitHub organization (default: Ma-Lab2)
  --ssh-host <host>        SSH host alias in ~/.ssh/config (default: github.com)
  --token-env <ENV>        Token env var name (default: GH_TOKEN)
  --format <fmt>           Output format: table|tsv|json (default: table)
  --include-private        Include private repos in API query (default: true via type=all)
  -h, --help               Show help

Examples:
  list-accessible-repos.sh --org Ma-Lab2 --ssh-host github-small
  list-accessible-repos.sh --org Ma-Lab2 --format json
USAGE
}

ORG="Ma-Lab2"
SSH_HOST="github.com"
TOKEN_ENV="GH_TOKEN"
FORMAT="table"
INCLUDE_PRIVATE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)
      ORG="$2"
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
    --format)
      FORMAT="$2"
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
      echo "[ERROR] Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$FORMAT" != "table" && "$FORMAT" != "tsv" && "$FORMAT" != "json" ]]; then
  echo "[ERROR] --format must be one of: table, tsv, json"
  exit 1
fi

TOKEN="${!TOKEN_ENV:-}"
if [[ -z "$TOKEN" ]]; then
  echo "[ERROR] Environment variable $TOKEN_ENV is missing"
  exit 1
fi

python3 - "$ORG" "$SSH_HOST" "$TOKEN" "$FORMAT" "$INCLUDE_PRIVATE" <<'PY'
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request

org, ssh_host, token, output_format, include_private = sys.argv[1:]

headers = {
    "Accept": "application/vnd.github+json",
    "Authorization": f"Bearer {token}",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "list-accessible-repos",
}

repo_type = "all" if include_private == "true" else "public"
url = f"https://api.github.com/orgs/{urllib.parse.quote(org)}/repos?per_page=100&type={repo_type}"
repos = []

while url:
    req = urllib.request.Request(url=url, headers=headers, method="GET")
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
        if not isinstance(payload, list):
            raise SystemExit(f"GitHub API returned non-list payload: {payload}")
        repos.extend(payload)
        link = resp.headers.get("Link", "")

    next_url = ""
    if link:
        for part in [p.strip() for p in link.split(",")]:
            if 'rel="next"' in part:
                next_url = part[part.find("<") + 1 : part.find(">")]
                break
    url = next_url

rows = []
for repo in sorted(repos, key=lambda x: x["name"].lower()):
    name = repo["name"]
    visibility = "private" if repo.get("private") else "public"
    ssh_url = f"git@{ssh_host}:{org}/{name}.git"

    check = subprocess.run(
        ["bash", "-lc", f"timeout 20s git ls-remote --heads {ssh_url} >/dev/null 2>&1"],
        capture_output=True,
        text=True,
    )
    pullable = check.returncode == 0

    rows.append(
        {
            "name": name,
            "visibility": visibility,
            "pullable": pullable,
            "ssh_url": ssh_url,
        }
    )

if output_format == "json":
    print(json.dumps({"org": org, "count": len(rows), "repos": rows}, ensure_ascii=False, indent=2))
elif output_format == "tsv":
    print("name\tvisibility\tpullable\tssh_url")
    for r in rows:
        print(f"{r['name']}\t{r['visibility']}\t{'YES' if r['pullable'] else 'NO'}\t{r['ssh_url']}")
else:
    print(f"Organization: {org}")
    print(f"Total repositories: {len(rows)}")
    print("| Repository | Visibility | Pullable via SSH | SSH URL |")
    print("|---|---|---|---|")
    for r in rows:
        pullable = "YES" if r["pullable"] else "NO"
        print(f"| {r['name']} | {r['visibility']} | {pullable} | `{r['ssh_url']}` |")
PY
