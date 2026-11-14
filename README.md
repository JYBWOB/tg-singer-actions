# tg-singer-actions

通过 GitHub Actions 和 [`tg-signer`](https://github.com/amchii/tg-signer) 自动完成 Telegram 机器人签到。

当前工作流固定使用 `tg-signer 0.9.2`，避免上游发布新版本后未经验证地改变运行结果。

## 工作方式

- GitHub Actions 按 `.github/workflows/main.yml` 中的 cron 定时启动。
- 签到会话保存在仓库 Secret `TG_SESSION_STRING` 中。
- `tg-signer export` 生成的原生 JSON 配置保存在 Secret `TG_SIGNER_CONFIG` 中。
- 每次 Action 调用 `run-once github-actions`，实际执行时间只由 GitHub cron 决定。
- Session 只在 runner 内存中加载，不会提交到仓库。

## 快速开始

### 1. Fork 并克隆仓库

Fork 本仓库到自己的 GitHub 账号，然后克隆自己的 Fork：

```bash
git clone https://github.com/YOUR_NAME/tg-singer-actions.git
cd tg-singer-actions
```

Fork 不会继承本仓库的 Secrets。GitHub 通常也会暂停 Fork 中的工作流，需要在自己仓库的 **Actions** 页面确认并启用工作流。

### 2. 一键生成并上传配置

需要：

- Python 3.10 或更高版本
- 可以接收 Telegram 登录验证码的账号
- 可选：Telegram 代理地址，例如 `socks5://127.0.0.1:7890`
- 可选：已安装并登录 [GitHub CLI](https://cli.github.com/)，用于自动上传 Secrets 和触发测试

运行：

```bash
bash scripts/setup.sh
```

脚本会在登录前询问可选的代理地址。也可以通过环境变量预先提供，脚本不会显示地址：

```bash
TG_PROXY='socks5://127.0.0.1:7890' bash scripts/setup.sh
```

该代理会用于脚本内的所有 `tg-signer` 命令。`tg-signer` 不会自动读取操作系统的代理设置。

脚本会：

1. 在 `~/.local/share/tg-singer-actions` 创建隔离的 Python 环境；
2. 安装 `tg-signer 0.9.2`；
3. 交互登录 Telegram，并列出最近对话和 Chat ID；
4. 调用 `tg-signer reconfig github-actions` 交互生成签到配置；
5. 导出标准的 `tg-signer` JSON 配置；
6. 如果 GitHub CLI 已登录，询问是否上传两个必需 Secrets、启用工作流并立即测试；配置了代理时，还可选择上传 `TG_PROXY` Secret。

本机的 `127.0.0.1` 或 `localhost` 代理无法从 GitHub runner 访问，因此脚本不会默认上传代理。只有代理地址可从公网 runner 访问时，才应确认上传。

如果脚本无法识别目标仓库，可以显式指定：

```bash
bash scripts/setup.sh YOUR_NAME/tg-singer-actions
```

脚本不会输出 Session String。运行状态、最近对话元数据和日志都存入 `~/.local/share/tg-singer-actions`，不会写入克隆仓库。凭据文件权限为仅当前用户可读：

```text
~/.local/share/tg-singer-actions/session/my_account.session_string
~/.local/share/tg-singer-actions/sign-config.json
```

Session String 等同于 Telegram 账号登录凭据。不要提交、分享或粘贴到 Issue 中。

### 3. 设置执行时间

编辑 `.github/workflows/main.yml` 中这一行：

```yaml
- cron: "30 2 * * *"
```

GitHub Actions 的 cron 使用 **UTC**，不读取 `TZ` 变量。常用示例：

| 期望时间 | cron |
|---|---|
| 北京时间每天 08:00 | `0 0 * * *` |
| 北京时间每天 10:30 | `30 2 * * *` |
| 北京时间每天 23:15 | `15 15 * * *` |
| UTC 每 6 小时 | `17 */6 * * *` |

建议避开整点，因为 GitHub 在高峰期可能延迟定时任务。修改后提交并推送到自己 Fork 的默认分支：

```bash
git add .github/workflows/main.yml
git commit -m "Configure check-in schedule"
git push
```

仓库变量 `TZ` 默认是 `Asia/Shanghai`，用于 `tg-signer` 内部解析时间，但不能动态改变 GitHub cron。需要其他时区时，可以创建 Repository Variable `TZ`。

### 4. 手动测试

配置完成后，在仓库的 Actions 页面选择 **Telegram automatic check-in**，运行 `workflow_dispatch`。

也可以使用 GitHub CLI：

```bash
gh workflow run main.yml
gh run watch
```

Action 日志会保留 `tg-signer` 的正常输出和错误信息，便于排查 Chat ID、按钮文本、Session 失效或 Telegram 限流问题。

## 手动生成配置

不使用辅助脚本时，可以直接运行以下命令。请在仓库外的安全目录操作，避免误提交 Session 文件。

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install "tg-signer[speedup]==0.9.2"

# 如需代理，必须显式设置；tg-signer 不读取系统代理。
export TG_PROXY='socks5://127.0.0.1:7890'
tg-signer --in-memory login
tg-signer reconfig github-actions
tg-signer export --file sign-config.json github-actions
```

登录后会生成 `my_account.session_string`。在自己 Fork 的 **Settings → Secrets and variables → Actions** 中创建：

| Secret | 内容 | 必需 |
|---|---|---|
| `TG_SESSION_STRING` | `my_account.session_string` 的完整内容 | 是 |
| `TG_SIGNER_CONFIG` | `sign-config.json` 的完整内容 | 是 |
| `TG_PROXY` | `socks5://host:port` 等代理地址 | 否 |
| `TG_API_ID` | 自定义 Telegram API ID | 否 |
| `TG_API_HASH` | 自定义 Telegram API Hash | 否 |
| `OPENAI_API_KEY` | 图片识别或计算题动作使用的 API Key | 否 |
| `OPENAI_BASE_URL` | OpenAI 兼容接口地址 | 否 |
| `OPENAI_MODEL` | OpenAI 兼容模型名 | 否 |

也可以通过 GitHub CLI 上传：

```bash
gh secret set TG_SESSION_STRING < my_account.session_string
gh secret set TG_SIGNER_CONFIG < sign-config.json
```

`SIGN_CONFIG_DEMO.json` 展示了原生配置结构。它只用于参考，示例 Chat ID 无法直接签到。一个任务的 `chats` 数组可以配置多个机器人或群组，不再需要旧版 `TASK_MAP` 外层包装。

## 从旧版 Secrets 迁移

工作流会优先读取新的 `TG_SESSION_STRING` 和 `TG_SIGNER_CONFIG`。为了让已有 Fork 平滑迁移，它也暂时兼容旧名称 `SESSION_STRING` 和旧版 `TASK_MAP`，并在运行时把旧任务逐个导入 `tg-signer 0.9.2`。

已有用户可以先保持旧 Secrets 继续签到，再运行：

```bash
bash scripts/setup.sh
```

脚本上传新的两个 Secrets 后，工作流会自动切换到原生单任务配置。确认新配置运行成功后，可以删除旧的 `SESSION_STRING` 和 `TASK_MAP` Secrets。

## 更新签到配置

重新运行辅助脚本即可覆盖配置：

```bash
bash scripts/setup.sh
```

或者手动重新配置并上传：

```bash
tg-signer reconfig github-actions
tg-signer export --file sign-config.json github-actions
gh secret set TG_SIGNER_CONFIG < sign-config.json
```

配置中的 `sign_at` 和 `random_seconds` 是 `tg-signer` 本地调度字段。GitHub 工作流使用 `run-once`，因此它们不会改变 Action 的启动时间。

## 定时工作流保活

GitHub 可能停用长期没有仓库活动的公共仓库定时工作流。`.github/workflows/keepalive.yml` 每月运行两次，并向 Fork 的默认分支推送一个空提交。两次运行之间保留了重试余量，同时把保活权限与签到权限分开：

- `main.yml` 只有 `contents: read`；
- `keepalive.yml` 单独使用 `contents: write`。

如果不希望产生保活提交，可以在 Actions 中禁用 **Keep scheduled workflows active**。禁用后若定时工作流因长期无活动而停止，需要手动重新启用。

分支保护规则可能阻止保活工作流推送，但不会影响签到工作流本身。

## 常见问题

### 提示缺少 Secret

新用户应确认 Secret 名称严格为 `TG_SESSION_STRING` 和 `TG_SIGNER_CONFIG`。已有用户仍可使用迁移兼容的 `SESSION_STRING` 和 `TASK_MAP`。Fork 不会复制上游仓库的任何 Secrets。

### Session 失效

重新运行 `bash scripts/setup.sh`。如果旧 Session 无法复用，先将本地 Session 文件移到安全备份位置，再重新登录：

```bash
mv ~/.local/share/tg-singer-actions/session/my_account.session_string \
  ~/.local/share/tg-singer-actions/session/my_account.session_string.bak
bash scripts/setup.sh
```

### 找不到机器人、群组或按钮

先在 Telegram 客户端与目标会话交互，再重新登录以刷新最近对话。确认配置中的 Chat ID、话题 ID、发送文本和按钮文本完全正确。

### 定时任务没有准点执行

GitHub 不保证 schedule 准点运行，繁忙时可能延迟。确认 cron 使用 UTC、工作流位于默认分支且 Actions 已启用。

## 版本升级

升级 `tg-signer` 时，应同时修改并验证以下位置：

- `.github/workflows/main.yml` 中的 `TG_SIGNER_VERSION`；
- `scripts/setup.sh` 中的 `TG_SIGNER_VERSION`；
- README 中的版本说明。

先手动运行工作流验证新版，再提交升级，避免未固定版本导致定时签到突然失效。

## 上游文档

- [`tg-signer` 0.9.2 发布页](https://github.com/amchii/tg-signer/releases/tag/0.9.2)
- [`tg-signer` 使用说明](https://github.com/amchii/tg-signer#readme)
- [GitHub Actions schedule 文档](https://docs.github.com/actions/using-workflows/events-that-trigger-workflows#schedule)
- [GitHub Actions Secrets 文档](https://docs.github.com/actions/security-guides/using-secrets-in-github-actions)
