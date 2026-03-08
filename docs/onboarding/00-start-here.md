# 00 - 先看这里（Start Here）

这是课题组成员使用 `laser-plasma-github-governance` 的统一入口。  
先确认运行环境和鉴权方式，再按身份进入对应路径。

## 你是谁

- 普通成员（Contributor）：去看 `10-member-path.md`
- 管理员（Maintainer/Admin）：去看 `20-admin-path.md`
- 使用 AI 客户端（Codex / Claude Code / Cursor）：先看 `30-ai-agents.md`

## 先分清两件事

- `SSH`：推荐用于日常 `git clone` / `git pull` / `git push`
- `GH_TOKEN`：用于治理脚本、组织审计、GitHub API

这两个配置互不替代。  
你能用 SSH push，并不代表审计脚本就一定能跑；反过来也一样。

## 先判断你当前跑在哪个环境

- `WSL`：推荐把 `GH_TOKEN` 放在 `~/.bash_profile`
- `Windows 原生终端`（PowerShell / Git Bash / Cursor Windows 终端）：把 `GH_TOKEN` 放在当前用户环境变量或对应 shell profile
- 不确定时，先运行自检脚本，它会标出当前是 `wsl`、`windows-native` 还是其他环境

## 三步起步

1. 进入治理仓库根目录：
```bash
cd /path/to/laser-plasma-github-governance
```

2. 检查 `GH_TOKEN` 是否就绪：
```bash
echo ${GH_TOKEN:+SET}
```

如果你在 `WSL`，建议先执行：
```bash
source ~/.bash_profile
```

3. 运行上手自检：
```bash
./scripts/onboarding-check.sh --org Ma-Lab2 --repo laser-plasma-github-governance
```

4. 如果你准备日常协作代码，再验证 SSH：
```bash
ssh -T git@github.com
```

首次配置时 GitHub 常见返回是：
- 成功：`You've successfully authenticated`
- 失败：`Permission denied (publickey)`

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
- `WSL` 和 `Windows` 的环境变量、SSH key、ssh-agent 可能不是同一套，换环境后要重新确认。
