#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


def add_finding(findings: list[dict[str, str]], severity: str, code: str, message: str) -> None:
    findings.append({"severity": severity, "code": code, "message": message})


def summarize(findings: list[dict[str, str]]) -> dict[str, int]:
    counts = {"blocker": 0, "warning": 0, "info": 0}
    for finding in findings:
        sev = finding.get("severity")
        if sev in counts:
            counts[sev] += 1
    return counts


def github_get(url: str, token: str) -> tuple[int, Any]:
    req = urllib.request.Request(
        url=url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "governance-audit-skill",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            text = resp.read().decode("utf-8")
            return resp.getcode(), json.loads(text) if text else {}
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(text) if text else {}
        except json.JSONDecodeError:
            payload = {"message": text.strip()}
        return exc.code, payload
    except urllib.error.URLError as exc:
        return 0, {"message": str(exc)}


def main() -> int:
    parser = argparse.ArgumentParser(description="Check GitHub platform policy for one repository")
    parser.add_argument("--org", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--token-env", default="GH_TOKEN")
    parser.add_argument("--required-check", action="append", default=[])
    parser.add_argument("--required-approvals", type=int, default=1)
    parser.add_argument("--output", choices=["json", "text"], default="json")
    args = parser.parse_args()

    token = os.getenv(args.token_env, "").strip()
    findings: list[dict[str, str]] = []
    platform: dict[str, Any] = {
        "default_branch": None,
        "branch_protection": {"enabled": False},
        "required_checks": {"required": args.required_check, "configured": [], "missing": []},
        "required_reviews": {"required": args.required_approvals, "current": 0},
    }

    if not token:
        add_finding(findings, "blocker", "missing_token", f"Environment variable {args.token_env} is required")
        payload = {"repo": args.repo, "platform": platform, "summary": summarize(findings), "findings": findings}
        if args.output == "json":
            print(json.dumps(payload, ensure_ascii=False, indent=2))
        else:
            print(f"[FAIL] {args.repo}: missing token env {args.token_env}")
        return 1

    repo_url = f"https://api.github.com/repos/{urllib.parse.quote(args.org)}/{urllib.parse.quote(args.repo)}"
    status, repo_payload = github_get(repo_url, token)
    if status != 200:
        msg = repo_payload.get("message", "unknown error")
        add_finding(findings, "blocker", "repo_api_failed", f"Failed to read repository metadata ({status}): {msg}")
        payload = {"repo": args.repo, "platform": platform, "summary": summarize(findings), "findings": findings}
        if args.output == "json":
            print(json.dumps(payload, ensure_ascii=False, indent=2))
        else:
            print(f"[FAIL] {args.repo}: repository metadata read failed ({status})")
        return 1

    default_branch = repo_payload.get("default_branch") or "main"
    platform["default_branch"] = default_branch

    protection_url = (
        f"https://api.github.com/repos/{urllib.parse.quote(args.org)}/"
        f"{urllib.parse.quote(args.repo)}/branches/{urllib.parse.quote(default_branch)}/protection"
    )
    status, protection_payload = github_get(protection_url, token)

    if status == 200:
        platform["branch_protection"]["enabled"] = True

        required_status_checks = protection_payload.get("required_status_checks") or {}
        configured_contexts = list(required_status_checks.get("contexts") or [])
        for item in required_status_checks.get("checks") or []:
            context = (item or {}).get("context")
            if context and context not in configured_contexts:
                configured_contexts.append(context)
        platform["required_checks"]["configured"] = configured_contexts

        missing = [c for c in args.required_check if c not in configured_contexts]
        platform["required_checks"]["missing"] = missing
        if missing:
            add_finding(
                findings,
                "blocker",
                "missing_required_checks",
                "Missing required status checks: " + ", ".join(missing),
            )

        required_reviews = protection_payload.get("required_pull_request_reviews") or {}
        current = int(required_reviews.get("required_approving_review_count") or 0)
        platform["required_reviews"]["current"] = current
        if current < args.required_approvals:
            add_finding(
                findings,
                "blocker",
                "insufficient_required_reviews",
                (
                    f"Required approving reviews for {default_branch} is {current}, "
                    f"expected >= {args.required_approvals}"
                ),
            )
    elif status == 404:
        add_finding(
            findings,
            "blocker",
            "branch_protection_not_enabled",
            f"Branch protection is not enabled for default branch {default_branch}",
        )
    else:
        msg = protection_payload.get("message", "unknown error")
        add_finding(
            findings,
            "blocker",
            "branch_protection_unreadable",
            f"Unable to read branch protection ({status}): {msg}",
        )

    payload = {"repo": args.repo, "platform": platform, "summary": summarize(findings), "findings": findings}
    if args.output == "json":
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        counts = payload["summary"]
        print(
            f"{args.repo}: blockers={counts['blocker']} warnings={counts['warning']} info={counts['info']} "
            f"branch_protection={platform['branch_protection']['enabled']}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
