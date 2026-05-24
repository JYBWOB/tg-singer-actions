#!/usr/bin/env python3
"""添加签到任务：配置签到、导出配置、生成 workflow 文件

用法: python scripts/add-task.py <task_name> [cron_expression]
示例: python scripts/add-task.py linuxdo "30 8 * * *"
"""

import sys
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("用法: python scripts/add-task.py <task_name> [cron_expression]")
        print('示例: python scripts/add-task.py linuxdo "30 8 * * *"')
        print("\n  task_name       签到任务名称（已在 tg-signer 中配置好的）")
        print("  cron_expression 北京时间 cron 表达式（默认: 0 8 * * *）")
        sys.exit(1)

    task_name = sys.argv[1]
    cron = sys.argv[2] if len(sys.argv) > 2 else "0 8 * * *"

    project_dir = Path(__file__).resolve().parent.parent
    config_file = Path(f".signer/signs/{task_name}/config.json")
    workflow_file = project_dir / f".github/workflows/sign-{task_name}.yml"

    # 步骤 1: 读取配置
    print("=== 步骤 1: 读取签到配置 ===")
    if not config_file.exists():
        print(f"错误: 配置文件 {config_file} 不存在")
        print(f"请先运行 tg-signer run {task_name} 完成配置")
        sys.exit(1)

    task_upper = task_name.upper()
    config_content = config_file.read_text(encoding="utf-8")
    print(f"配置内容（请设置为 GitHub Secret: SIGN_CONFIG_{task_upper}）：")
    print("---")
    print(config_content)
    print("---")

    # 步骤 2: 生成 workflow 文件
    print("\n=== 步骤 2: 生成 Workflow 文件 ===")
    workflow_file.parent.mkdir(parents=True, exist_ok=True)
    workflow_content = f'''name: "签到 - {task_name}"

on:
  schedule:
    - cron: "{cron}"
      timezone: Asia/Shanghai
  workflow_dispatch:

jobs:
  sign:
    runs-on: ubuntu-latest
    env:
      TZ: Asia/Shanghai
    steps:
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.10"

      - name: Install tg-signer
        run: pip install tg-signer

      - name: Write sign config
        run: |
          mkdir -p .signer/signs/{task_name}
          echo '${{{{ secrets.SIGN_CONFIG_{task_upper} }}}}' > .signer/signs/{task_name}/config.json

      - name: Run sign task
        env:
          TG_SESSION_STRING: ${{{{ secrets.TG_SESSION_STRING }}}}
        run: tg-signer --session-string "$TG_SESSION_STRING" --in-memory run-once {task_name}
'''
    workflow_file.write_text(workflow_content, encoding="utf-8")
    print(f"已生成: {workflow_file}")
    print(f"\n=== 完成 ===")
    print(f"接下来请：")
    print(f"  1. 将上面的配置内容添加为 GitHub Secret: SIGN_CONFIG_{task_upper}")
    print(f"  2. 提交并推送: git add .github/workflows/ && git commit -m '添加签到任务 {task_name}' && git push")
    print(f"  3. 在 GitHub Actions 页面手动触发测试")

if __name__ == "__main__":
    main()
