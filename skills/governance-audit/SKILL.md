---
name: governance-audit
description: Organization-level GitHub governance audit for research teams using strict versioned collaboration. Use when checking whether repositories installed the governance skill, enforce VERSION/CHANGELOG/OWNERS baselines, validate lock/hash integrity, and verify branch protection required checks before allowing ongoing pull/push workflows.
---

# Governance Audit

## Overview

Run a read-only audit across all repositories in an organization and produce machine-readable and human-readable reports.

## Workflow

1. Export a GitHub token with org repository read permission:
```bash
export GH_TOKEN=<token>
```
2. Run organization audit:
```bash
./skills/governance-audit/scripts/run-org-audit.sh --org Ma-Lab2
```
3. Read summary:
- `report.md`
- `report.json`
4. Drill down each repository result in `results/<repo>.md` and `results/<repo>.json`.

## Command Reference

```bash
./skills/governance-audit/scripts/run-org-audit.sh \
  --org Ma-Lab2 \
  --required-skill-version 0.2.1 \
  --token-env GH_TOKEN \
  --fail-on-blocker true
```

- `--org`: target GitHub organization.
- `--required-skill-version`: minimum installed governance skill version in each repository.
- `--repo-list`: optional fixed repo list file.
- `--fail-on-blocker`: return non-zero when any blocker exists (CI friendly).
- `--required-check`: required status check names for default branch protection.
- `--required-approvals`: minimum required approving reviews.

## Platform Policy Checks

Use `scripts/check-platform-policy.py` to validate repository-level GitHub settings:
- branch protection enabled on default branch
- required checks present:
  - `governance/validate-pr-fields`
  - `governance/validate-version`
- required approvals >= 1

## References

- Audit policy and interpretation: `references/audit-policy.md`
