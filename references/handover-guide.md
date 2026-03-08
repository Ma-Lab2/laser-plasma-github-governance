# Handover Guide

## Policy

Every project must always have at least two maintainers.

## Graduation Handover Timeline

1. T-30 days: outgoing maintainer announces graduation and names successor candidate.
2. T-21 days: successor shadows issue triage, CI failures, and releases.
3. T-14 days: pair-maintain one full release cycle.
4. T-7 days: transfer repository admin permissions if needed.
5. T-0 day: finalize handover checklist in `docs/HANDOVER.md`.

## Required Handover Artifacts

- current `VERSION` and latest tag
- open bugs and risk list
- release procedure notes
- infrastructure secrets ownership map
- CI/CD known failure patterns
- contact list of stakeholders

## Exit Criteria

- successor can perform pull workflow from tag
- successor can create release PR and tag without help
- project still has at least two maintainers in `OWNERS.yaml`
