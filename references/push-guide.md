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

After updating governance files, refresh lock metadata:

```bash
python3 .governance/update-skill-lock.py --skill-version 0.2.1
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
- `.governance/skill.lock.json` missing or invalid
- `.governance/manifest.sha256` hash checks fail
- installed governance skill version is below required minimum
- `VERSION` format is invalid
- `VERSION` changed without `CHANGELOG.md`
- commits lack `Base-Version`
- release change lacks matching `Target-Version`
- `AI-Agent` is missing or invalid
- `AI-Assistance` is missing or invalid
- `Human-Review-Confirmed` is not `yes`
