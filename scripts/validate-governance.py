#!/usr/bin/env python3
import argparse
import re
import subprocess
import sys
from pathlib import Path

SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
TAGVER = re.compile(r"^v[0-9]+\.[0-9]+\.[0-9]+$")
BASE_TRAILER = re.compile(r"^Base-Version:\s*(v[0-9]+\.[0-9]+\.[0-9]+)\s*$", re.MULTILINE)
TARGET_TRAILER = re.compile(r"^Target-Version:\s*(v[0-9]+\.[0-9]+\.[0-9]+)\s*$", re.MULTILINE)

REQUIRED_FILES = [
    "VERSION",
    "CHANGELOG.md",
    "OWNERS.yaml",
    "CONTRIBUTING.md",
    "CODEOWNERS",
    "docs/HANDOVER.md",
    ".pre-commit-config.yaml",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/workflows/governance-check.yml",
    ".github/workflows/release-tag-check.yml",
]


def run_git(args):
    proc = subprocess.run(["git", *args], text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip())
    return proc.stdout.strip()


def check_required_files(root: Path, errors: list[str]):
    for rel in REQUIRED_FILES:
        if not (root / rel).exists():
            errors.append(f"Missing required file: {rel}")


def read_version(root: Path, errors: list[str]):
    path = root / "VERSION"
    if not path.exists():
        return None
    version = path.read_text(encoding="utf-8").strip()
    if not SEMVER.match(version):
        errors.append(f"VERSION must match MAJOR.MINOR.PATCH, got: {version}")
        return None
    return version


def check_owners(root: Path, errors: list[str]):
    path = root / "OWNERS.yaml"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    maintainers = re.findall(r"^\s*-\s*github:\s*@?[A-Za-z0-9-]+\s*$", text, flags=re.MULTILINE)
    if len(maintainers) < 2:
        errors.append("OWNERS.yaml must define at least two maintainers")


def changed_files(base_ref: str, head_ref: str):
    out = run_git(["diff", "--name-only", f"{base_ref}...{head_ref}"])
    return [line for line in out.splitlines() if line.strip()]


def commits_in_range(base_ref: str, head_ref: str):
    out = run_git(["rev-list", f"{base_ref}..{head_ref}"])
    return [line for line in out.splitlines() if line.strip()]


def commit_message(commit: str):
    return run_git(["show", "-s", "--format=%B", commit])


def validate_commit_trailers(base_ref: str, head_ref: str, expected_target: str | None, errors: list[str]):
    commits = commits_in_range(base_ref, head_ref)
    if not commits:
        return

    target_found = False
    for c in commits:
        msg = commit_message(c)
        if not BASE_TRAILER.search(msg):
            errors.append(f"Commit {c[:8]} missing Base-Version trailer")
        target_matches = TARGET_TRAILER.findall(msg)
        if target_matches:
            if expected_target and expected_target in target_matches:
                target_found = True
            for t in target_matches:
                if not TAGVER.match(t):
                    errors.append(f"Commit {c[:8]} has invalid Target-Version: {t}")

    if expected_target and not target_found:
        errors.append(f"Expected Target-Version trailer not found in commits: {expected_target}")


def validate_expected_tag(version: str | None, expected_tag: str, errors: list[str]):
    if not TAGVER.match(expected_tag):
        errors.append(f"Tag must match vMAJOR.MINOR.PATCH, got: {expected_tag}")
        return
    if version and expected_tag != f"v{version}":
        errors.append(f"Tag {expected_tag} does not match VERSION v{version}")


def main():
    parser = argparse.ArgumentParser(description="Validate repository governance rules")
    parser.add_argument("--mode", choices=["local", "ci"], default="local")
    parser.add_argument("--base-ref", default="")
    parser.add_argument("--head-ref", default="HEAD")
    parser.add_argument("--expected-tag", default="")
    args = parser.parse_args()

    root = Path.cwd()
    errors: list[str] = []

    check_required_files(root, errors)
    version = read_version(root, errors)
    check_owners(root, errors)

    if args.expected_tag:
        validate_expected_tag(version, args.expected_tag, errors)

    if args.base_ref:
        try:
            files = changed_files(args.base_ref, args.head_ref)
        except RuntimeError as exc:
            errors.append(f"Unable to compute changed files: {exc}")
            files = []

        version_changed = "VERSION" in files
        changelog_changed = "CHANGELOG.md" in files
        expected_target = f"v{version}" if version_changed and version else None

        if version_changed and not changelog_changed:
            errors.append("VERSION changed but CHANGELOG.md was not updated")

        try:
            validate_commit_trailers(args.base_ref, args.head_ref, expected_target, errors)
        except RuntimeError as exc:
            errors.append(f"Unable to validate commit trailers: {exc}")

    if errors:
        print("[FAIL] Governance validation failed:")
        for err in errors:
            print(f"- {err}")
        return 1

    print("[OK] Governance validation passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
