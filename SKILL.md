---
name: laser-plasma-github-governance
description: Governance framework for GitHub organizations used by research groups that need strict, versioned collaboration across many repositories. Use when creating project repositories, enforcing pull/push version rules, requiring PR-based merges, standardizing CHANGELOG/OWNERS/CONTRIBUTING files, and handling maintainer handover so projects remain maintainable after student graduation.
---

# Laser Plasma GitHub Governance

## Overview

Use this skill to build and enforce a repository governance baseline for a laser-plasma research group. Keep every project independently versioned, auditable, and transferable.

## Workflow

1. Initialize governance in each repository from `assets/repo-template/`.
2. Enable branch protection and required status checks in GitHub.
3. Require contributors to start work from a version tag using `scripts/start-from-tag.sh`.
4. Require each commit message to include `Base-Version: vMAJOR.MINOR.PATCH`.
5. Require release PRs to include `Target-Version: vMAJOR.MINOR.PATCH` and keep `VERSION` aligned with `CHANGELOG.md`.
6. Enforce at least two maintainers and graduation handover rules via `OWNERS.yaml` and `docs/HANDOVER.md`.
7. Enforce machine-verifiable skill installation with `.governance/skill.lock.json` and `.governance/manifest.sha256`.

## Mandatory Governance Rules

- Enforce per-repository independent versioning with root `VERSION`.
- Use SemVer (`MAJOR.MINOR.PATCH`) and tags as `vMAJOR.MINOR.PATCH`.
- Disallow direct pushes to default branch; merge through PR only.
- Require at least one maintainer approval before merge.
- Require pull by explicit version tag baseline.
- Require each project to keep at least two maintainers.
- Require each project to pass skill installation checks (skill version + hash integrity).

## Execution Checklist

1. Copy `assets/repo-template/` into the target repository root.
2. Update placeholders in `OWNERS.yaml`, `CODEOWNERS`, and `CONTRIBUTING.md`.
3. Refresh governance lock and manifest:
```bash
python3 .governance/update-skill-lock.py --skill-version 0.2.0
```
4. Install local hooks:
```bash
pre-commit install
pre-commit install --hook-type commit-msg
```
5. Add branch protections:
- Require PR before merging
- Require at least 1 approval
- Require checks:
  - `governance/validate-version`
  - `governance/validate-pr-fields`
6. Create initial baseline tag:
```bash
git tag v0.1.0
git push origin v0.1.0
```

## Scripts

- `scripts/start-from-tag.sh <tag> [branch-name]`: create a clean work branch from a required tag baseline.
- `scripts/prepare-release.sh <major|minor|patch> <base-tag>`: bump `VERSION`, append `CHANGELOG`, and create a release commit with required trailers.
- `scripts/validate-governance.py`: validate governance files, versioning, commit trailers, placeholder replacement, and skill installation lock/hash integrity.
- `scripts/update-skill-lock.py`: update `.governance/skill.lock.json` and `.governance/manifest.sha256`.
- `scripts/apply-governance-template.sh <target-repo> [skill-version]`: apply template and refresh skill lock files in one step.
- `scripts/audit-org-repos.sh`: organization-wide audit report including skill installation status.
- `scripts/check-commit-trailer.sh <commit-msg-file>`: commit-msg hook for `Base-Version` trailer enforcement.

## References

- Repository creation and onboarding: `references/project-creation-guide.md`
- Pull/version baseline process: `references/pull-guide.md`
- Push/PR/release process: `references/push-guide.md`
- Graduation handover process: `references/handover-guide.md`

## Notes

- Apply this governance to both new and existing repositories.
- Keep automation strict in CI and fast locally with pre-commit hooks.
- Treat `VERSION` as the single source of truth for repository version state.
