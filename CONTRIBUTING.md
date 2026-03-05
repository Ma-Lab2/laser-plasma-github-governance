# Contributing

## Governance Rules

- Do not push directly to the default branch.
- Open PR for all changes.
- Include `Base-Version` trailer in every commit message.
- Use SemVer in `VERSION` and matching tags.

## Development Baseline

For feature work in governed repositories, start from an explicit tag:

```bash
scripts/start-from-tag.sh v0.1.0 feature/your-change
```

## Commit Message Example

```text
feat: improve audit output

Base-Version: v0.1.0
```

## Skill Lock Update

After changing governance files, refresh lock metadata:

```bash
python3 .governance/update-skill-lock.py --skill-version 0.2.1
```

## Release Commit

```bash
scripts/prepare-release.sh patch v0.2.1
```

## Pull Request Requirements

Fill PR template fields:

- `Base-Version:`
- `Change-Type:`
- `Target-Version:` (use `N/A` for non-release PRs)
- `AI-Agent:` (`codex|claude-code|cursor|copilot|other|none`)
- `AI-Assistance:` (`none|low|medium|high`)
- `Human-Review-Confirmed:` (`yes` required)
- `AI-Notes:` short summary or `N/A`
