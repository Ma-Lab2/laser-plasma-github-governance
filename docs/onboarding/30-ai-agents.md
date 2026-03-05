# 30 - AI 客户端路径（Codex / Claude Code / Cursor）

目标：不同客户端使用同一套底层治理脚本，结果一致。

## 通用原则（所有客户端）

- 不直接改治理规则，优先调用仓库脚本。
- PR 必填 AI 字段：
  - `AI-Agent`
  - `AI-Assistance`
  - `Human-Review-Confirmed: yes`
  - `AI-Notes`
- 人工 reviewer 必须确认最终变更。

## Codex

- 治理执行入口：`$laser-plasma-github-governance`
- 审计入口：`$governance-audit`
- 建议把目标命令明确给 agent，例如：
```bash
./skills/governance-audit/scripts/run-org-audit.sh --org Ma-Lab2 --fail-on-blocker false
```

## Claude Code

- 在仓库终端中执行与 Codex 相同的脚本命令。
- 优先让 Claude 调用仓库已有脚本，不要让其重复造同类脚本。

## Cursor

- 在 Cursor 内置终端运行同一命令。
- 让 Cursor 改文件时，要求它引用现有治理文件路径，避免偏离模板。

## 客户端差异处理建议

- 规划能力强：先让 agent 输出“执行清单”再执行。
- 写代码能力强：先跑 `onboarding-check.sh`，确认环境再改。
- 遇到认证弹窗：统一使用非交互命令与 token 环境变量。

