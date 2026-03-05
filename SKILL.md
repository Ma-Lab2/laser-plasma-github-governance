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

## Mandatory Governance Rules

- Enforce per-repository independent versioning with root `VERSION`.
- Use SemVer (`MAJOR.MINOR.PATCH`) and tags as `vMAJOR.MINOR.PATCH`.
- Disallow direct pushes to default branch; merge through PR only.
- Require at least one maintainer approval before merge.
- Require pull by explicit version tag baseline.
- Require each project to keep at least two maintainers.

## Execution Checklist

1. Copy `assets/repo-template/` into the target repository root.
2. Update placeholders in `OWNERS.yaml`, `CODEOWNERS`, and `CONTRIBUTING.md`.
3. Install local hooks:
```bash
pre-commit install
pre-commit install --hook-type commit-msg
```
4. Add branch protections:
- Require PR before merging
- Require at least 1 approval
- Require checks:
  - `governance/validate-version`
  - `governance/validate-pr-fields`
5. Create initial baseline tag:
```bash
git tag v0.1.0
git push origin v0.1.0
```

## Scripts

- `scripts/start-from-tag.sh <tag> [branch-name]`: create a clean work branch from a required tag baseline.
- `scripts/prepare-release.sh <major|minor|patch> <base-tag>`: bump `VERSION`, append `CHANGELOG`, and create a release commit with required trailers.
- `scripts/validate-governance.py`: validate required files, semantic version format, changelog coupling, maintainer minimums, commit trailers, and tag alignment.
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
