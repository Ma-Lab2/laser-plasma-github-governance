# 40 - 常见问题（FAQ）

## Q1: 我已经写了 `~/.bashrc`，为什么脚本还说 `GH_TOKEN` 缺失？

很多非交互 shell 不会执行 `~/.bashrc` 后半段。  
建议把 token 放在 `~/.bash_profile`，并执行：

```bash
source ~/.bash_profile
echo ${GH_TOKEN:+SET}
```

## Q2: 一直弹 GitHub 登录框怎么办？

这通常是 credential manager 交互认证触发。  
治理脚本已采用非交互模式。若你手动执行 git 命令，建议加：

```bash
GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never
```

## Q3: 普通成员为什么不能直接 push 到 main？

这是治理要求，不是故障。  
必须用分支 + PR，CI 会验证版本与审计字段。

## Q4: 如何判断自己是管理员还是普通成员？

- 能配置 branch protection、管理仓库设置：管理员路径。
- 只提交代码、提 PR：普通成员路径。

## Q5: token 能不能发到聊天让 agent 帮我配置？

不能。  
token 一旦泄露，必须立刻 revoke 并重建。

