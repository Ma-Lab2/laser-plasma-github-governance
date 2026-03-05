# 20 - 管理员路径（Admin Path）

适用对象：仓库维护者、组织管理员、课题组技术负责人。

## 目标

- 新仓库可立即进入可治理状态
- 组织级持续审计可运行
- 毕业交接时项目可延续

## 新仓库初始化

1. 克隆目标仓库并应用治理模板：
```bash
./scripts/apply-governance-template.sh /path/to/target-repo 0.2.1
```

2. 在目标仓库替换占位符：
- `OWNERS.yaml`
- `CODEOWNERS`
- `docs/HANDOVER.md`
- `CONTRIBUTING.md`

3. 刷新 lock 信息：
```bash
python3 .governance/update-skill-lock.py --skill-version 0.2.1
```

4. 初始化版本标签（若仓库尚无标签）：
```bash
git tag v0.1.0
git push origin v0.1.0
```

## 分支保护最小要求

- 禁止直接 push 默认分支
- Require PR before merging
- 至少 1 个 review approval
- 必须通过检查：
  - `governance/validate-pr-fields`
  - `governance/validate-version`

## 组织级审计

先运行不阻断模式看全量问题：
```bash
./skills/governance-audit/scripts/run-org-audit.sh \
  --org Ma-Lab2 \
  --fail-on-blocker false
```

修复完成后运行阻断模式：
```bash
./skills/governance-audit/scripts/run-org-audit.sh \
  --org Ma-Lab2 \
  --fail-on-blocker true
```

## 交接要求

每个项目至少 2 名维护者，交接流程见：
- `references/handover-guide.md`
- `docs/HANDOVER.md`

