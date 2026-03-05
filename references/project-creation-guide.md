# Project Creation Guide

## Goal

Create repositories that are governable from day one and survive maintainer turnover.

## Steps

1. Create repository in the GitHub organization.
2. Copy all files from `assets/repo-template/` into repository root.
3. Replace placeholder GitHub usernames in:
- `OWNERS.yaml`
- `CODEOWNERS`
- `CONTRIBUTING.md`
4. Refresh governance lock and manifest:
```bash
python3 .governance/update-skill-lock.py --skill-version 0.2.0
```
5. Commit template baseline and open the first PR.
6. Merge the PR and create initial tag `v0.1.0`.
7. Configure branch protections and required checks.

## Required Branch Protection

- Block direct pushes to default branch.
- Require pull request before merge.
- Require at least 1 approval.
- Require status checks:
  - `governance/validate-version`
  - `governance/validate-pr-fields`

## Audit Checklist

- `VERSION` exists and matches SemVer.
- `CHANGELOG.md` contains `## [Unreleased]`.
- `OWNERS.yaml` includes at least 2 maintainers.
- `docs/HANDOVER.md` exists and has current maintainer list.
- `.governance/skill.lock.json` and `.governance/manifest.sha256` exist and pass validation.
