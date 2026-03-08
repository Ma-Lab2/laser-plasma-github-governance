# 30 - AI 客户端路径（Codex / Claude Code / Cursor）

目标：不同客户端使用同一套底层治理脚本，结果一致。

先明确一件事：`Codex`、`Claude Code`、`Cursor` 不是独立操作系统。  
真正决定配置位置的是它们跑在 `WSL` 还是 `Windows 原生终端`。

## 通用原则（所有客户端）

- 不直接改治理规则，优先调用仓库脚本。
- 先运行 `./scripts/onboarding-check.sh`，确认当前 runtime、SSH、token 状态。
- PR 必填 AI 字段：
  - `AI-Agent`
  - `AI-Assistance`
  - `Human-Review-Confirmed: yes`
  - `AI-Notes`
- 人工 reviewer 必须确认最终变更。
- 日常 Git 推荐走 `SSH`；审计和 API 访问需要 `GH_TOKEN`。

## 先判断 agent 跑在哪

- 如果 agent 跑在 `WSL` 终端：
  - `GH_TOKEN` 通常来自 `~/.bash_profile`
  - SSH key 通常在 `~/.ssh/`
- 如果 agent 跑在 `Windows 原生`：
  - `GH_TOKEN` 来自 Windows 用户环境变量或 shell profile
  - SSH key 走 Windows 用户目录下的 `.ssh`

如果不确定，直接运行：
```bash
./scripts/onboarding-check.sh --org Ma-Lab2 --repo laser-plasma-github-governance
```

## Codex

- 治理执行入口：`$laser-plasma-github-governance`
- 审计入口：`$governance-audit`
- Codex 使用哪个环境，取决于你从哪个终端启动它。
- 建议把目标命令明确给 agent，例如：
```bash
./skills/governance-audit/scripts/run-org-audit.sh --org Ma-Lab2 --fail-on-blocker false
```

## Claude Code

- 在仓库终端中执行与 Codex 相同的脚本命令。
- 优先让 Claude 调用仓库已有脚本，不要让其重复造同类脚本。
- 如果 Claude Code 在 Windows 终端里运行，就不要假设它能读取 WSL 里的 `GH_TOKEN` 或 SSH key。

## Cursor

- 在 Cursor 内置终端运行同一命令。
- 让 Cursor 改文件时，要求它引用现有治理文件路径，避免偏离模板。
- Cursor 的 Windows 终端和 WSL 终端是两套环境，认证配置不能混为一谈。

## 客户端差异处理建议

- 规划能力强：先让 agent 输出“执行清单”再执行。
- 写代码能力强：先跑 `onboarding-check.sh`，确认环境再改。
- 遇到认证弹窗：统一使用非交互命令与 token 环境变量。
