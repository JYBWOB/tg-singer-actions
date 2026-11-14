#!/usr/bin/env bash
set -Eeuo pipefail

TG_SIGNER_VERSION="${TG_SIGNER_VERSION:-0.9.2}"
TG_PROXY="${TG_PROXY:-}"
TASK_NAME="github-actions"
DATA_DIR="${TG_SIGNER_DATA_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/tg-singer-actions}"
VENV_DIR="${DATA_DIR}/venv"
SESSION_DIR="${DATA_DIR}/session"
WORK_DIR="${DATA_DIR}/workdir"
LOG_DIR="${DATA_DIR}/logs"
LOG_FILE="${LOG_DIR}/tg-signer.log"
CONFIG_FILE="${DATA_DIR}/sign-config.json"
SESSION_FILE="${SESSION_DIR}/my_account.session_string"
REPOSITORY="${1:-}"

fail() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  local answer
  read -r -p "${prompt} [Y/n] " answer
  [[ -z "${answer}" || "${answer}" =~ ^[Yy]$ ]]
}

command -v python3 >/dev/null 2>&1 || fail "未找到 python3（需要 Python 3.10 或更高版本）"
python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' \
  || fail "Python 版本过低，需要 Python 3.10 或更高版本"

umask 077
mkdir -p "${DATA_DIR}" "${SESSION_DIR}" "${WORK_DIR}" "${LOG_DIR}"

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  printf '创建独立 Python 环境：%s\n' "${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
fi

printf '安装 tg-signer %s...\n' "${TG_SIGNER_VERSION}"
"${VENV_DIR}/bin/python" -m pip install --disable-pip-version-check --quiet \
  --upgrade "tg-signer[speedup]==${TG_SIGNER_VERSION}"
TG_SIGNER="${VENV_DIR}/bin/tg-signer"

if [[ -z "${TG_PROXY}" ]]; then
  printf '\ntg-signer 不读取系统代理。如需通过代理连接 Telegram，请在下方输入。\n'
  read -r -s -p 'Telegram 代理地址（例如 socks5://127.0.0.1:7890，直接回车跳过）: ' TG_PROXY || true
  printf '\n'
fi
if [[ -n "${TG_PROXY}" ]]; then
  export TG_PROXY
  printf '已为本次 tg-signer 配置代理（地址已隐藏）。\n'
fi

"${TG_SIGNER}" --log-dir "${LOG_DIR}" --log-file "${LOG_FILE}" version

printf '\n登录 Telegram。已有会话会自动复用，并重新列出最近对话。\n'
"${TG_SIGNER}" \
  --log-dir "${LOG_DIR}" \
  --log-file "${LOG_FILE}" \
  --session_dir "${SESSION_DIR}" \
  --workdir "${WORK_DIR}" \
  --in-memory \
  login

[[ -s "${SESSION_FILE}" ]] || fail "没有生成 ${SESSION_FILE}"
chmod 600 "${SESSION_FILE}"

printf '\n开始配置签到任务。配置中的执行时间仅供 tg-signer 本地运行使用；GitHub Actions 的时间由 workflow cron 决定。\n'
"${TG_SIGNER}" --log-dir "${LOG_DIR}" --log-file "${LOG_FILE}" --workdir "${WORK_DIR}" reconfig "${TASK_NAME}"
"${TG_SIGNER}" --log-dir "${LOG_DIR}" --log-file "${LOG_FILE}" --workdir "${WORK_DIR}" export --file "${CONFIG_FILE}" "${TASK_NAME}"
[[ -s "${CONFIG_FILE}" ]] || fail "没有生成 ${CONFIG_FILE}"
chmod 600 "${CONFIG_FILE}"

printf '\n配置已生成：\n  Session: %s\n  签到配置: %s\n' "${SESSION_FILE}" "${CONFIG_FILE}"
printf '这些文件包含敏感信息，请勿提交、分享或粘贴到 Issue。\n'

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  printf '\n未检测到已登录的 GitHub CLI。请在 Fork 仓库中手动创建 Secrets：\n'
  printf '  TG_SESSION_STRING  <- %s\n' "${SESSION_FILE}"
  printf '  TG_SIGNER_CONFIG   <- %s\n' "${CONFIG_FILE}"
  exit 0
fi

if [[ -z "${REPOSITORY}" ]]; then
  REPOSITORY="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
fi

if [[ -z "${REPOSITORY}" ]]; then
  printf '\n无法识别 Fork 仓库。可指定仓库后重新运行：\n'
  printf '  bash scripts/setup.sh YOUR_NAME/tg-singer-actions\n'
  exit 0
fi

printf '\n检测到 GitHub 仓库：%s\n' "${REPOSITORY}"
if confirm "将 Session 和签到配置上传为该仓库的 Actions Secrets？"; then
  gh secret set TG_SESSION_STRING --repo "${REPOSITORY}" < "${SESSION_FILE}"
  gh secret set TG_SIGNER_CONFIG --repo "${REPOSITORY}" < "${CONFIG_FILE}"

  if [[ -n "${TG_PROXY}" ]]; then
    printf '当前代理可能只在本机可用；GitHub runner 无法访问 127.0.0.1 或 localhost。\n'
    if confirm "确认该代理可从 GitHub runner 访问，并上传为 TG_PROXY Secret？"; then
      printf '%s' "${TG_PROXY}" | gh secret set TG_PROXY --repo "${REPOSITORY}"
      printf '代理 Secret 已上传。\n'
    fi
  fi

  printf 'Secrets 已上传。\n'

  for workflow in main.yml keepalive.yml; do
    if gh workflow enable "${workflow}" --repo "${REPOSITORY}" >/dev/null 2>&1; then
      printf '已启用工作流：%s\n' "${workflow}"
    else
      printf '提示：无法自动启用 %s，请到仓库 Actions 页面手动启用。\n' "${workflow}"
    fi
  done

  if confirm "现在手动运行一次签到工作流进行测试？"; then
    gh workflow run main.yml --repo "${REPOSITORY}"
    printf '工作流已触发。查看日志：\n  gh run watch --repo %s\n' "${REPOSITORY}"
  fi
fi
