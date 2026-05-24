# tg-signer GitHub Actions 每日自动签到

通过 GitHub Actions 定时执行 [tg-signer](https://github.com/amchii/tg-signer) 签到任务。每个任务独立配置触发时间。

## 前置条件

- 本地已安装 Python >= 3.10
- 拥有 Telegram 账号

## 快速开始

### 1. 安装 tg-signer 并登录

```bash
pip install tg-signer
tg-signer login
```

根据提示输入手机号和验证码完成登录。

### 2. 导出 Session String

```bash
python scripts/export-session.py
```

复制输出的字符串，在 GitHub 仓库 **Settings > Secrets and variables > Actions** 中添加为 `TG_SESSION_STRING`。

### 3. 添加签到任务

```bash
python scripts/add-task.py <task_name> [cron表达式]
```

示例：

```bash
python scripts/add-task.py linuxdo "30 8 * * *"   # 每天北京时间 8:30
python scripts/add-task.py another "0 12 * * *"   # 每天北京时间 12:00
```

脚本会自动：
1. 读取已有的 config.json 并输出内容（需设置为 GitHub Secret `SIGN_CONFIG_<TASK_NAME>`）
2. 生成对应的 workflow 文件 `.github/workflows/sign-<task_name>.yml`

### 4. 配置 GitHub Secrets

在 GitHub 仓库 **Settings > Secrets and variables > Actions** 中添加：

| Secret 名称 | 值 |
|---|---|
| `TG_SESSION_STRING` | 步骤 2 导出的 session string |
| `SIGN_CONFIG_<TASK_NAME>` | 步骤 3 输出的 config.json 内容（如 `SIGN_CONFIG_LINUXDO`） |

### 5. 推送并测试

```bash
git add .github/workflows/
git commit -m "添加签到任务"
git push
```

在 GitHub 仓库的 **Actions** 页面手动触发 workflow 验证是否正常运行。

## 添加新任务

```bash
python scripts/add-task.py <new_task> "0 9 * * *"
```

然后将配置添加为 GitHub Secret，提交推送 workflow 文件即可。

## 手动配置（不使用脚本）

如果不想使用辅助脚本，也可以手动操作：

1. `tg-signer export --session-string` 获取 session string
2. `tg-signer run <task>` 配置任务，复制 `.signer/signs/<task>/config.json`
3. 复制 `.github/workflows/sign-example.yml`，修改任务名、cron 时间和 secret 名称
4. 设置 GitHub Secrets 并推送

## 注意事项

- GitHub Actions 的 cron 调度可能有几分钟延迟，这是正常现象
- 仓库已配置每周自动保活（`keepalive.yml`），无需担心 60 天无活动被禁用
- 请勿将 session string 或签到配置直接提交到仓库中
