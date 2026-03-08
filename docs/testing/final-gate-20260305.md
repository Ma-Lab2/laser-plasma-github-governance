# Final Gate Test Report (2026-03-05)

## Scope

One-pass closeout validation for:

- onboarding environment checks
- organization governance audit
- error-path behavior (missing/invalid token)
- deterministic audit summaries across repeated runs

## Executed Test Matrix

1. `onboarding-check.sh` with missing `GH_TOKEN`
- Expected: non-zero exit with blocker findings
- Result: pass (`EXIT=1`, blocker present)

2. `onboarding-check.sh` with valid `GH_TOKEN`
- Expected: zero exit, no blocker
- Result: pass (`EXIT=0`, `pass=7`, `warn=1`, `blocker=0`)

3. `run-org-audit.sh` with invalid token
- Expected: non-zero exit with organization-level auth failure
- Result: pass (`EXIT=1`, `org_repo_list_failed`)

4. `run-org-audit.sh --fail-on-blocker true` (run #1)
- Expected: zero exit only when blocker repos are zero
- Result: pass (`EXIT=0`, blocker repos = 0)

5. `run-org-audit.sh --fail-on-blocker true` (run #2)
- Expected: same summary as run #1
- Result: pass (summary identical)

## Final Audit Snapshot

From `/tmp/finalcheck-org-audit-20260305-155537/report.md`:

- repositories: `5`
- blocker_repos: `0`
- warning_repos: `2`
- installed_repos: `5`
- content_blocker_repos: `0`
- platform_blocker_repos: `0`

Warning-only repositories:

- `demo-repository`
- `laser-plasma-github-governance`

Warning code:

- `branch_protection_not_enabled` (treated as warning in current governance mode)

## Acceptance Decision

Final gate accepted for current governance mode:

- Hard blockers: cleared
- Content governance: fully compliant
- Residual warnings: known and explicitly accepted

## Artifact Paths

- `/tmp/final-gate-20260305-155802/onboarding-missing.json`
- `/tmp/final-gate-20260305-155802/onboarding-ok.json`
- `/tmp/final-gate-20260305-155802/audit-bad-token/report.md`
- `/tmp/final-gate-20260305-155802/audit-strict-1/report.json`
- `/tmp/final-gate-20260305-155802/audit-strict-2/report.json`
- `/tmp/finalcheck-org-audit-20260305-155537/report.md`
