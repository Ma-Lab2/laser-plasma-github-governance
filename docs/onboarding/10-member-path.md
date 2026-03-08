# 10 - 普通成员路径（Member Path）

适用对象：组内项目贡献者，不负责组织级配置。

## 目标

- 开发从明确版本基线开始
- 提交满足版本追踪规则
- PR 字段完整且可审计
- 本地拉取/推送链路稳定，不被 SSH 或 token 配置反复阻塞

## 开发流程

1. 先做成员预检：
```bash
./scripts/member-preflight.sh --org Ma-Lab2 --repo <your-repo> --ssh-host github-small
```

2. 克隆仓库（稳健模式）：
```bash
./scripts/clone-repo.sh \
  --org Ma-Lab2 \
  --repo <your-repo> \
  --ssh-host github-small \
  --https-fallback
```

3. 同步 tags 并从标签开分支：
```bash
git fetch --tags --prune
./.governance/start-from-tag.sh vX.Y.Z feature/your-branch
```

4. 开发并提交（每个 commit 都要带 Base-Version）：
```bash
./scripts/commit-with-base.sh \
  --base-version vX.Y.Z \
  --summary "feat: your change summary" \
  --body "why this change is needed"
```

5. 推送并提 PR（不直接推 main）：
```bash
git push origin feature/your-branch
```

6. 生成 PR Governance 字段草稿（必填）：
```bash
./scripts/gen-pr-template.sh \
  --base-version vX.Y.Z \
  --change-type feat \
  --target-version N/A \
  --ai-agent codex \
  --ai-assistance medium
```

7. PR 必填字段：
- `Base-Version`
- `Change-Type`
- `Target-Version`
- `AI-Agent`
- `AI-Assistance`
- `Human-Review-Confirmed: yes`
- `AI-Notes`

## 常见被拒原因与修复

- 缺 `Base-Version` trailer：使用 `./scripts/commit-with-base.sh` 重提 commit。
- 改了 `VERSION` 但没改 `CHANGELOG.md`：补 `CHANGELOG.md` 后重新推送。
- `AI-Agent` / `AI-Assistance` / `Human-Review-Confirmed` 缺失：重新生成或补齐 PR 字段。
- 直接推默认分支失败：这是预期行为，改为分支 + PR。
- `git clone` 卡住：先 `./scripts/cleanup-git-hang.sh --repo Ma-Lab2/<your-repo>`，再用 `clone-repo.sh --https-fallback` 重试。
