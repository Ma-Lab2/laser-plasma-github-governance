# Laser Plasma GitHub Governance

Governance skill for Ma-Lab2 repositories.

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
./scripts/audit-org-repos.sh --org Ma-Lab2
```
