---
name: laser-plasma-github-governance
description: Governance framework for GitHub organizations used by research groups that need strict, versioned collaboration across many repositories. Use when creating project repositories, enforcing pull/push version rules, requiring PR-based merges, standardizing CHANGELOG/OWNERS/CONTRIBUTING files, handling maintainer handover, and enforcing AI-agent disclosure with human review so projects remain maintainable after student graduation.
---

# Laser Plasma GitHub Governance

## Overview

Use this skill to enforce a repository governance baseline for a laser-plasma research group. Keep every project independently versioned, auditable, and transferable across student turnover.

## Workflow

1. Initialize governance in each repository from `assets/repo-template/`.
2. Enable branch protection and required checks in GitHub.
3. Require contributors to start work from explicit tags.
4. Require commit trailers (`Base-Version`, optionally `Target-Version`).
5. Require lock-based skill installation checks (`skill.lock.json`, `manifest.sha256`).
6. Require AI-agent disclosure and human-review confirmation in every PR.
7. Use onboarding guides for role-specific setup and execution:
   - `docs/onboarding/00-start-here.md`
   - `docs/onboarding/10-member-path.md`
   - `docs/onboarding/20-admin-path.md`
   - `docs/onboarding/30-ai-agents.md`

## Mandatory Governance Rules

- Enforce per-repository versioning with root `VERSION`.
- Use SemVer (`MAJOR.MINOR.PATCH`) and tags `vMAJOR.MINOR.PATCH`.
- Disallow direct pushes to default branch.
- Require PR approvals and CI checks.
- Require at least two maintainers in `OWNERS.yaml`.
- Require `.governance/skill.lock.json` and `.governance/manifest.sha256` to be valid.
- Require PR metadata fields: `AI-Agent`, `AI-Assistance`, `Human-Review-Confirmed`, `AI-Notes`.

## Execution Checklist

1. Copy `assets/repo-template/` into target repo root.
2. Replace placeholders in `OWNERS.yaml`, `CODEOWNERS`, and `docs/HANDOVER.md`.
3. Refresh lock metadata:
```bash
python3 .governance/update-skill-lock.py --skill-version 0.2.1
```
4. Install local hooks:
```bash
pre-commit install
pre-commit install --hook-type commit-msg
```
5. Configure branch protection checks:
- `governance/validate-pr-fields`
- `governance/validate-version`
6. Create baseline tag if missing:
```bash
git tag v0.1.0
git push origin v0.1.0
```

## AI-Agent Policy

- Allowed `AI-Agent`: `codex`, `claude-code`, `cursor`, `copilot`, `other`, `none`.
- Allowed `AI-Assistance`: `none`, `low`, `medium`, `high`.
- `Human-Review-Confirmed` must be `yes` for merge.
- `AI-Notes` must summarize agent contribution or be `N/A`.

## Scripts

- `scripts/start-from-tag.sh <tag> [branch-name]`
- `scripts/prepare-release.sh <major|minor|patch> <base-tag>`
- `scripts/check-commit-trailer.sh <commit-msg-file>`
- `scripts/validate-governance.py`
- `scripts/update-skill-lock.py`
- `scripts/apply-governance-template.sh <target-repo> [skill-version]`
- `scripts/audit-org-repos.sh`
- `scripts/install-governance-audit-skill.sh`
- `scripts/onboarding-check.sh`
- `skills/governance-audit/scripts/run-org-audit.sh`

## References

- `references/project-creation-guide.md`
- `references/pull-guide.md`
- `references/push-guide.md`
- `references/handover-guide.md`

## Notes

- Apply this governance to new and existing repositories.
- Keep CI strict and local hooks fast.
- Treat `VERSION` as source of truth for repository version state.
