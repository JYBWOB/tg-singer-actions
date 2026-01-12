# tg-singer-actions
使用[tg-signer](https://github.com/amchii/tg-signer)通过github action实现每日自动化签到

# 使用方法
1. fork本仓库并在你自己的仓库最后续步骤
2. 修改`.github/workflows/main.yml`中的`on.schedule.cron`来指定每日运行时间
3. 仓库中设置以下repository secrets：

    a. SESSION_STRING="your_session_string"

    b. TASK_MAP="your_task_map" (格式见`TASK_MAP_DEMO.json`，任务配置可通过本地tg-signer设置好任务后获取)
4. 测试action