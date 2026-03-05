# 00 - 先看这里（Start Here）

这是课题组成员使用 `laser-plasma-github-governance` 的统一入口。  
先完成环境配置，再按身份进入对应路径。

## 你是谁

- 普通成员（Contributor）：去看 `10-member-path.md`
- 管理员（Maintainer/Admin）：去看 `20-admin-path.md`
- 使用 AI 客户端（Codex / Claude Code / Cursor）：先看 `30-ai-agents.md`

## 三步起步

1. 进入治理仓库根目录：
```bash
cd /path/to/laser-plasma-github-governance
```

2. 加载环境变量并检查 token：
```bash
source ~/.bash_profile
echo ${GH_TOKEN:+SET}
```

3. 运行上手自检：
```bash
./scripts/onboarding-check.sh --org Ma-Lab2 --repo laser-plasma-github-governance
```

## 常用命令（复制即用）

安装审核 skill（本机全局）：
```bash
./scripts/install-governance-audit-skill.sh
```

组织审计（先不阻断，先看报告）：
```bash
./skills/governance-audit/scripts/run-org-audit.sh \
  --org Ma-Lab2 \
  --fail-on-blocker false
```

## 安全提醒

- 不要把 token 写入仓库文件。
- 不要把 token 发到聊天、Issue、PR 评论。
- 如果 token 泄露，立即在 GitHub revoke 并重建。

