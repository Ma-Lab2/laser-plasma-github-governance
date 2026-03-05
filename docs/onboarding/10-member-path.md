# 10 - 普通成员路径（Member Path）

适用对象：组内项目贡献者，不负责组织级配置。

## 目标

- 开发从明确版本基线开始
- 提交满足版本追踪规则
- PR 字段完整且可审计

## 开发流程

1. 同步 tags 并从标签开分支：
```bash
git fetch --tags --prune
./.governance/start-from-tag.sh vX.Y.Z feature/your-branch
```

2. 开发并提交（每个 commit 都要带 Base-Version）：
```bash
git commit -m "your change summary" -m "Base-Version: vX.Y.Z"
```

3. 推送并提 PR（不直接推 main）：
```bash
git push origin feature/your-branch
```

4. 填写 PR Governance 字段（必填）：
- `Base-Version`
- `Change-Type`
- `Target-Version`
- `AI-Agent`
- `AI-Assistance`
- `Human-Review-Confirmed: yes`
- `AI-Notes`

## 常见被拒原因与修复

- 缺 `Base-Version` trailer：
  - 重新整理 commit message，补 trailer 后再 push。
- 改了 `VERSION` 但没改 `CHANGELOG.md`：
  - 补 `CHANGELOG.md` 的对应记录。
- `AI-Agent` / `AI-Assistance` / `Human-Review-Confirmed` 缺失：
  - 补齐 PR 模板字段。
- 直接推默认分支失败：
  - 这是预期行为，改为分支 + PR。

