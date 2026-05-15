# HarnessTemplates

AI Coding Agent 的长时任务脚手架模板——一次导入，终身复用，自动更新。

让 AI agent 在多轮会话中保持连续性、可追溯性和可验证性。人类下达命令后，agent 能够自我迭代和验证，直到任务完成或触发人工介入。

## 快速开始

```bash
# 安装 harness CLI
curl -fsSL https://raw.githubusercontent.com/BeamusWayne/HarnessTemplates/main/install.sh | bash

# 在项目中初始化
cd your-project
harness init
```

初始化完成后，项目会获得以下文件：

```
your-project/
├── CLAUDE.md              # Claude Code 根指令
├── AGENTS.md              # 其他 agent 根指令
├── init.sh                # 环境初始化脚本
├── feature_list.json      # 功能清单与状态追踪
├── claude-progress.md     # 跨会话进度日志
├── evaluator-rubric.md    # 质量评审评分表
├── .harness/
│   ├── config.json        # harness 配置（版本、定制状态）
│   ├── templates/         # 上游模板原始副本（用于 diff）
│   ├── scripts/           # 验证脚本
│   ├── plans/             # 执行计划
│   └── histories/         # 变更记录
```

## 命令速查

| 命令 | 用途 |
|------|------|
| `harness init` | 初始化项目（一行命令生成所有文件） |
| `harness upgrade` | 拉取上游模板更新（交互式处理定制文件） |
| `harness status` | 显示版本、功能进度、定制情况 |
| `harness check` | 运行结构完整性检查（`--fix` 自动修复） |
| `harness diff <file>` | 对比项目文件与上游模板 |
| `harness adopt <file>` | 放弃本地修改，接受上游版本 |
| `harness customize <file>` | 标记文件为已定制（upgrade 不自动更新） |
| `harness uncustomize <file>` | 取消定制标记 |
| `harness new-plan <name>` | 创建执行计划 |
| `harness new-history <name>` | 创建变更记录 |
| `harness report` | 生成工作总结（功能进度、变更统计） |
| `harness doctor` | 诊断问题（版本、文件、配置） |
| `harness changelog` | 显示版本变更日志 |

### 常用选项

- `--auto` — upgrade 时跳过交互，自动更新未定制文件
- `--dry-run` — 只显示将做什么，不实际执行
- `--fix` — check 时自动修复问题（CRLF、权限）
- `--local` — 从本地模板复制（开发/测试用）
- `--non-interactive` — init 时跳过交互，使用自动检测的项目配置

## 模板文件

### 框架文件（可自动更新）

| 文件 | 用途 |
|------|------|
| `CLAUDE.md` | Claude Code 根指令文件 |
| `AGENTS.md` | Codex 等其他 agent 根指令文件 |
| `init.sh` | 环境初始化脚本（支持 `health`、`verify` 子命令） |
| `evaluator-rubric.md` | 质量评审评分表 |
| `autonomous-loop.md` | 自治迭代循环协议 |
| `self-eval-trigger.md` | 自我评审触发协议 |

### 数据文件（永不自动更新）

| 文件 | 用途 |
|------|------|
| `feature_list.json` | 机器可读的功能清单与状态追踪 |
| `claude-progress.md` | 跨会话进度日志 |

### 脚手架文件（自动添加）

| 文件 | 用途 |
|------|------|
| `plan-template.md` | 执行计划模板 |
| `history-template.md` | 变更记录模板 |

### 参考文档

| 文件 | 内容 |
|------|------|
| [`method-map.md`](./.harness/reference/method-map.md) | 常见失败模式与对应修复工件 |
| [`initializer-agent-playbook.md`](./.harness/reference/initializer-agent-playbook.md) | 初始化阶段操作手册 |
| [`coding-agent-startup-flow.md`](./.harness/reference/coding-agent-startup-flow.md) | 每轮编码会话的固定流程 |
| [`prompt-calibration.md`](./.harness/reference/prompt-calibration.md) | 根指令文件的编写原则 |

## 典型工作流

```bash
# 1. 安装并初始化
harness init

# 2. 定制你需要的文件
harness customize CLAUDE.md

# 3. 日常开发
harness status                    # 查看进度
harness new-plan add-auth         # 创建执行计划
harness new-history auth-done     # 记录变更

# 4. 更新模板
harness upgrade                   # 交互式更新
harness upgrade --auto            # 自动更新未定制文件
harness diff CLAUDE.md            # 查看差异
harness adopt CLAUDE.md           # 接受上游版本

# 5. 诊断问题
harness check                     # 结构检查
harness doctor                    # 全面诊断
harness report                    # 工作总结
```

## 设计原则

- **仓库是唯一事实来源** — agent 不依赖聊天记录，所有状态持久化在文件中
- **一次一个功能** — 任何时候只有一个 active feature，避免范围蔓延
- **证据驱动完成** — 功能完成必须跑过验证并记录证据
- **数据永不覆盖** — upgrade 时数据文件（feature_list.json、claude-progress.md）永不触碰
- **定制优先** — 标记为定制的文件不会被自动更新，用户可选择 adopt 接受上游

## 自治迭代

项目内置三层自治循环结构（功能迭代 → 验证修复 → 构建测试），让 agent 在人类下达命令后自动迭代、验证和修复，直到所有功能完成或触发升级条件。

详见 `autonomous-loop.md` 和 `self-eval-trigger.md`。

## 安全注意事项

- `install.sh` 使用 `curl | bash` 安装模式。审查内容后再运行，或直接下载 `bin/harness` 手动安装到 `~/.local/bin/`
- harness CLI 只使用 GitHub 公开 API，不需要 token
- 模板中的 init.sh 使用保守默认值，请审查后再运行
- 所有写操作使用临时文件，确认后再移到目标位置

## Hooks 自动化

初始化后，harness 会自动配置以下强制机制：

| 机制 | 触发时机 | 作用 |
|------|---------|------|
| Claude Code PostToolUse hook | 每次代码修改后 | 检查是否有 in_progress 的功能 |
| Claude Code Stop hook | 会话结束前 | 检查 claude-progress.md 是否已更新 |
| Git pre-commit hook | 每次 git commit 前 | 验证 feature_list.json 和 claude-progress.md 完整性 |

这些机制确保 agent 的行为符合 harness 工作规则，不依赖 prompt 驱动。

## 系统要求

- Bash 4+（macOS / Linux / WSL2 / Git Bash）
- curl（用于从 GitHub 拉取模板）
- git（可选，用于版本管理）

## License

MIT
