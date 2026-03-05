# Changelog

All notable changes to this governance skill are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]

### Added
- Human-friendly onboarding docs:
  - `docs/onboarding/00-start-here.md`
  - `docs/onboarding/10-member-path.md`
  - `docs/onboarding/20-admin-path.md`
  - `docs/onboarding/30-ai-agents.md`
  - `docs/onboarding/40-faq.md`
- `scripts/onboarding-check.sh` for environment and access self-check.
- `skills/governance-audit` skill package (audit workflow, policy reference, platform checker).
- Weekly organization audit workflow: `.github/workflows/org-governance-audit-weekly.yml`.
- Audit skill installer: `scripts/install-governance-audit-skill.sh`.

### Changed
- `run-org-audit.sh` git authentication uses non-interactive basic token flow to avoid credential popup loops.
- Platform policy checker now treats `branch_protection_not_enabled` as warning in current governance mode.

### Verified
- Final gate test suite executed on 2026-03-05 and archived in:
  - `docs/testing/final-gate-20260305.md`

## [0.2.1] - 2026-03-05

### Added
- Mandatory AI-agent disclosure fields in PR templates.
- CI enforcement for `AI-Agent`, `AI-Assistance`, and `Human-Review-Confirmed: yes`.
- README onboarding for member pull/push behavior and AI-assisted workflow.

### Changed
- Required governance skill version upgraded from `0.2.0` to `0.2.1`.

## [0.2.0] - 2026-03-05

### Added
- Skill installation marker enforcement using `.governance/skill.lock.json`.
- Integrity manifest enforcement using `.governance/manifest.sha256`.
- Hash and version checks in governance validator for CI blocking.
- Organization audit report now includes skill installation/upgrade status.
- Governance template apply script and lock refresh script.

## [0.1.0] - 2026-03-05

### Added
- Initial governance skill, templates, and enforcement scripts.
