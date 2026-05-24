#!/usr/bin/env python3
"""导出 Telegram Session String"""

import subprocess
import sys
import shutil

if not shutil.which("tg-signer"):
    print("错误: 未安装 tg-signer，请先运行: pip install tg-signer")
    sys.exit(1)

print("=== 导出 Session String ===")
print("如果尚未登录，请先运行: tg-signer login\n")
subprocess.run(["tg-signer", "export", "--session-string"], check=True)
print("\n请将上面输出的字符串设置为 GitHub Secret: TG_SESSION_STRING")
