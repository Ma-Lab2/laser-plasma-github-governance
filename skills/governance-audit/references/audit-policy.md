# Governance Audit Policy

## Scope

The audit is read-only and evaluates two layers:

1. Repository content governance
- Required files (`VERSION`, `CHANGELOG.md`, `OWNERS.yaml`, governance hooks/workflows, lock/manifest).
- Skill installation lock integrity (`.governance/skill.lock.json`, `.governance/manifest.sha256`).
- Required governance skill minimum version.

2. GitHub platform governance
- Default branch protection enabled.
- Required checks include:
  - `governance/validate-pr-fields`
  - `governance/validate-version`
- Required approving reviews >= 1.

## Severity

- `blocker`: must be fixed before repository is considered compliant.
- `warning`: should be fixed soon but not immediately blocking.
- `info`: informational signal.

## Exit Policy

- Default mode is `--fail-on-blocker true`.
- Any blocker in any repository causes non-zero exit code.
- Use `--fail-on-blocker false` for exploratory runs that should not fail pipelines.

## Token Policy

- Token env var is mandatory.
- Missing token is treated as organization-level blocker.
- Token must be able to list organization repositories and read repository metadata.

## Output Contract

- `report.md`: high-level organization summary for maintainers.
- `report.json`: structured organization summary for automation.
- `results/<repo>.md`: repository-level human-readable findings.
- `results/<repo>.json`: repository-level machine-readable findings.
