# Laser Plasma GitHub Governance

Governance skill for Ma-Lab2 repositories.

## Start Here

New members and admins should start from the onboarding guide:

- `docs/onboarding/00-start-here.md`
- Member path: `docs/onboarding/10-member-path.md`
- Admin path: `docs/onboarding/20-admin-path.md`
- AI clients path: `docs/onboarding/30-ai-agents.md`
- FAQ: `docs/onboarding/40-faq.md`

Run onboarding self-check:

```bash
./scripts/onboarding-check.sh --org Ma-Lab2 --repo laser-plasma-github-governance
```

Before using the governance workflow, separate the two authentication jobs:

- `SSH` is recommended for daily `git clone` / `git pull` / `git push`
- `GH_TOKEN` is required for governance scripts, organization audit, and GitHub API access

Both `WSL` and `Windows native` shells are supported. The onboarding guide explains the correct setup path for each runtime.

## What This Repository Provides

- Governance template: `assets/repo-template/`
- Validation and audit scripts: `scripts/`
- Lock-based installation detection:
  - `.governance/skill.lock.json`
  - `.governance/manifest.sha256`

## Quick Start (For Maintainers)

```bash
./scripts/apply-governance-template.sh /path/to/target-repo 0.2.1
```

Then replace placeholders in `OWNERS.yaml`, `CODEOWNERS`, and `docs/HANDOVER.md`.

## What Happens When Members Pull

- If they have read permission, `git clone` / `git pull` works normally.
- If they do not have read permission, authentication fails.
- Daily Git transport should prefer SSH; HTTPS remains a fallback path.

## What Happens When Members Push

- If direct push to default branch is blocked (recommended), direct `push` to `main` fails.
- Members must open PRs.
- PR CI blocks merge if governance checks fail (versioning, lock/hash integrity, required fields, trailers).

## Required PR Governance Fields

- `Base-Version`
- `Change-Type`
- `Target-Version`
- `AI-Agent` (`codex|claude-code|cursor|copilot|other|none`)
- `AI-Assistance` (`none|low|medium|high`)
- `Human-Review-Confirmed` (`yes` required)
- `AI-Notes`

## Local Validation

```bash
python3 .governance/validate-governance.py --mode local --required-skill-version 0.2.1
```

## Organization Audit

```bash
./skills/governance-audit/scripts/run-org-audit.sh --org Ma-Lab2
```

## Install Audit Skill Globally

```bash
./scripts/install-governance-audit-skill.sh
```

This installs `governance-audit` into:

- `${CODEX_HOME:-$HOME/.codex}/skills/governance-audit`

Use in agent prompt:

- `$governance-audit`

## Weekly Organization Audit Workflow

- Workflow file: `.github/workflows/org-governance-audit-weekly.yml`
- Trigger: every Monday (UTC) + manual `workflow_dispatch`
- Required secret: `MA_LAB2_AUDIT_TOKEN`
