# Pull Guide

## Rule

Do not start work from an arbitrary branch head. Start from an explicit tag baseline.

## Workflow

```bash
git fetch --tags --prune
./.governance/start-from-tag.sh v1.2.3 feature/plasma-diagnostic
```

If the repository has no release tags yet, create baseline `v0.1.0` first.

## Why This Is Mandatory

- Prevent hidden drift from unknown branch states.
- Preserve reproducibility of scientific software states.
- Allow successor maintainers to recreate prior environments quickly.

## Pull Request Base-Version

Every commit in the PR must include trailer:

```text
Base-Version: v1.2.3
```

This trailer records the exact baseline version used for development.
