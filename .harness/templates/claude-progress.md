# 进度日志

## 当前已验证状态

- 仓库根目录：(项目路径)
- 标准启动路径：./init.sh
- 标准验证路径：./init.sh verify
- 当前最高优先级未完成功能：(待 AI 填写)
- 当前 blocker：无

## 重启路径

当会话因 token 预算不足或其他原因中断时，下一个会话应：

1. 运行 `pwd` 确认在正确目录
2. 读取本文件（claude-progress.md）
3. 读取 `feature_list.json` 查看当前功能状态
4. 运行 `git log --oneline -5` 查看最近提交
5. 运行 `./init.sh` 初始化环境
6. 运行 `touch .harness/.session-start` 刷新会话标记
7. 继续处理 `feature_list.json` 中优先级最高的未完成功能

## 会话记录

(每次会话结束前，由 AI 或人类在此添加记录)

## 自治迭代记录

（自治模式下由 agent 自动填写）

## 变更历史归档

完整的变更历史按月归档在 `.harness/histories/YYYY-MM/`。
每条记录使用 `.harness/templates/history-template.md` 格式。
创建新记录：`harness new-history <任务简述>`
