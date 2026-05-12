# HarnessTemplates

AI Coding Agent 的长时任务脚手架模板。

让 AI agent 在多轮会话中保持连续性、可追溯性和可验证性——人类下达命令后，agent 能够自我迭代和验证，直到任务完成或触发人工介入。

## 适用场景

- 需要 AI agent 连续工作多个功能、多轮会话的项目
- 需要明确的完成定义和验证证据的工作流
- 需要"双手离开键盘"、让 agent 自治运行的场景

## 快速开始

1. 把 `.harness/templates/` 下的文件复制到你的项目根目录
2. 按需修改命令、路径和功能名称
3. 让 agent 读取 `CLAUDE.md`（Claude Code）或 `AGENTS.md`（Codex 等其他 agent）
4. 运行 `./init.sh` 开始工作

详细使用说明见 [`.harness/templates/index.md`](./.harness/templates/index.md)。

## 模板文件

| 文件 | 用途 |
|------|------|
| `CLAUDE.md` | Claude Code 的根指令文件 |
| `AGENTS.md` | Codex 等其他 agent 的根指令文件 |
| `init.sh` | 环境初始化脚本 |
| `feature_list.json` | 机器可读的功能清单与状态追踪 |
| `claude-progress.md` | 跨会话进度日志 |
| `session-handoff.md` | 会话交接摘要 |
| `clean-state-checklist.md` | 收尾检查清单 |
| `evaluator-rubric.md` | 质量评审评分表 |
| `quality-document.md` | 代码库质量快照 |

## 参考文档

| 文件 | 内容 |
|------|------|
| [`method-map.md`](./.harness/reference/method-map.md) | 常见失败模式与对应修复工件 |
| [`initializer-agent-playbook.md`](./.harness/reference/initializer-agent-playbook.md) | 初始化阶段操作手册 |
| [`coding-agent-startup-flow.md`](./.harness/reference/coding-agent-startup-flow.md) | 每轮编码会话的固定流程 |
| [`prompt-calibration.md`](./.harness/reference/prompt-calibration.md) | 根指令文件的编写原则 |

## 设计原则

- **仓库是唯一事实来源** — agent 不依赖聊天记录，所有状态持久化在文件中
- **一次一个功能** — 任何时候只有一个 active feature，避免范围蔓延
- **证据驱动完成** — 功能完成必须跑过验证并记录证据
- **干净交接** — 每轮会话结束保证下一轮可以直接开工

## 自治迭代

项目包含自治迭代的修改方案，详见 [`自治迭代修改意见书.md`](./自治迭代修改意见书.md)。

方案核心：三层循环（功能迭代 → 验证修复 → 构建测试），让 agent 在人类下达命令后自动迭代、验证和修复，直到所有功能完成或触发升级条件。

## License

MIT
