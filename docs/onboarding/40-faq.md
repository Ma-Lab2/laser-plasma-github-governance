# 40 - 常见问题（FAQ）

## Q1: 我已经写了 `~/.bashrc`，为什么脚本还说 `GH_TOKEN` 缺失？

很多非交互 shell 不会执行 `~/.bashrc` 后半段。  
建议把 token 放在 `~/.bash_profile`，并执行：

```bash
source ~/.bash_profile
echo ${GH_TOKEN:+SET}
```

## Q2: 为什么我能 SSH push，但审计脚本还是报 token 问题？

因为两者用途不同：

- `SSH`：日常 Git 传输
- `GH_TOKEN`：治理脚本、组织审计、GitHub API

所以成员至少要明白：
- 写代码、pull/push：优先 SSH
- 跑治理脚本、组织审计：需要 token

## Q3: 一直弹 GitHub 登录框怎么办？

这通常是 credential manager 交互认证触发。  
治理脚本已采用非交互模式。若你手动执行 git 命令，建议加：

```bash
GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never
```

## Q4: 我在 Windows 配好了，为什么 WSL 里还是不生效？

因为 `Windows 原生` 和 `WSL` 是两套环境：

- 环境变量不共享
- `~/.ssh` 也可能不是同一目录
- ssh-agent 也可能不是同一个进程

切换环境后，重新检查：

```bash
echo ${GH_TOKEN:+SET}
ssh -T git@github.com
./scripts/onboarding-check.sh --org Ma-Lab2 --repo laser-plasma-github-governance
```

## Q5: 普通成员为什么不能直接 push 到 main？

这是治理要求，不是故障。  
必须用分支 + PR，CI 会验证版本与审计字段。

## Q6: 如何判断当前 agent 是在 WSL 还是 Windows 里跑？

不要猜。直接运行：

```bash
./scripts/onboarding-check.sh --org Ma-Lab2 --repo laser-plasma-github-governance
```

报告里的 `environment.runtime` 会标成：
- `wsl`
- `windows-native`
- `linux-native`
- `unknown`

## Q7: 如何判断自己是管理员还是普通成员？

- 能配置 branch protection、管理仓库设置：管理员路径。
- 只提交代码、提 PR：普通成员路径。

## Q8: token 能不能发到聊天让 agent 帮我配置？

不能。  
token 一旦泄露，必须立刻 revoke 并重建。
