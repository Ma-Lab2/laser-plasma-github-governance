# Push Guide

## Commit Message Requirements

Each commit must include:

```text
Base-Version: vMAJOR.MINOR.PATCH
```

Release commits must also include:

```text
Target-Version: vMAJOR.MINOR.PATCH
```

## Local Guard Rails

Install hooks:

```bash
pre-commit install
pre-commit install --hook-type commit-msg
```

## Release Workflow

```bash
./.governance/prepare-release.sh patch v1.2.3
git push origin HEAD
```

Then create tag and push:

```bash
git tag v1.2.4
git push origin v1.2.4
```

## CI Behavior

CI blocks merge when:

- required governance files are missing
- `VERSION` format is invalid
- `VERSION` changed without `CHANGELOG.md`
- commits lack `Base-Version`
- release change lacks matching `Target-Version`
