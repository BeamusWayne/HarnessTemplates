# HarnessTemplates

AI Coding Agent 的长时任务脚手架模板——一次导入，终身复用，自动更新。

让 AI agent 在多轮会话中保持连续性、可追溯性和可验证性。人类下达命令后，agent 能够自我迭代和验证，直到任务完成或触发人工介入。

## 快速开始

> 如果你是第一次使用，先读 [人类操作手册](./docs/human-guide.md)。其他文件（CLAUDE.md、autonomous-loop.md 等）是给 AI 读的，你不需要看。

```bash
# 1. 安装 harness CLI
curl -fsSL https://raw.githubusercontent.com/BeamusWayne/HarnessTemplates/main/install.sh | bash

# 2. 在项目中初始化
cd your-project
harness init

# 3. 打开 Claude Code（或你的 AI agent），告诉它你想做什么
#    例如："我要做一个带用户认证的博客系统"
#    AI 会帮你拆解功能、写入 feature_list.json，然后开始工作

# 4. 说"开始工作"，AI 按功能列表自动迭代
```

初始化完成后，项目会获得以下文件：

```
your-project/
├── CLAUDE.md              # Claude Code 根指令（AI 自动读取）
├── init.sh                # 环境初始化脚本
├── feature_list.json      # 功能清单（AI 帮你拆解后写入）
├── claude-progress.md     # 跨会话进度日志
├── evaluator-rubric.md    # 质量评审评分表
├── autonomous-loop.md     # 自治迭代循环协议
├── self-eval-trigger.md   # 自我评审触发协议
├── .claude/
│   └── settings.local.json # Claude Code hooks 配置
└── .harness/
    ├── config.json         # harness 配置（版本、定制状态、项目命令）
    ├── templates/          # 上游模板原始副本（用于 diff）
    ├── scripts/            # hook 脚本与验证脚本
    ├── reference/          # 参考文档（AI 按需读取）
    ├── plans/              # 执行计划
    ├── histories/          # 变更记录
    └── world/
        └── events.jsonl    # 事件流（会话、状态变迁、验证结果）
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
| `harness reset-status` | 重置 feature_list.json 为待规划状态 |
| `harness complete-plan` | 将执行计划从 active/ 移至 completed/ |
| `harness report` | 生成工作总结（功能进度、变更统计、事件时间线） |
| `harness query [pattern]` | 查询事件日志（`--today`、`--since`） |
| `harness doctor` | 诊断问题（版本、文件、配置） |
| `harness changelog` | 显示版本变更日志 |

### 常用选项

- `--auto` — upgrade 时跳过交互，自动更新未定制文件
- `--dry-run` — 只显示将做什么，不实际执行
- `--fix` — check 时自动修复问题（CRLF、权限）
- `--local` — 从本地模板复制（开发/测试用）
- `--non-interactive` — init 时跳过交互，使用自动检测的项目配置

## 工作流

### 人做的事

```bash
# 初始化
harness init

# 需要定制时（比如改 CLAUDE.md 适配你的项目）
harness customize CLAUDE.md

# 更新模板
harness upgrade                   # 交互式更新
harness upgrade --auto            # 自动更新未定制文件
harness diff CLAUDE.md            # 查看差异
harness adopt CLAUDE.md           # 接受上游版本

# 诊断问题
harness doctor                    # 全面诊断
harness check                     # 结构检查
harness status                    # 查看进度
```

### AI 做的事

AI 在工作过程中会自动：
- 读取 `feature_list.json` 选择下一个功能
- 运行 `./init.sh` 初始化环境
- 更新 `claude-progress.md` 记录进度
- 使用 `harness new-plan`、`harness new-history` 创建计划和记录
- 完成功能后更新 `feature_list.json` 状态
- 每轮结束前运行 `harness check` 确认状态干净
- 功能 blocked 时停下来报告原因，等你介入

### 定制指南

默认模板对大多数项目够用。需要定制时：

```bash
# 标记文件为已定制（upgrade 时不覆盖）
harness customize CLAUDE.md

# 编辑文件
# ...

# 查看定制了哪些文件
harness status
```

| 文件 | 什么时候定制 |
|------|------------|
| `CLAUDE.md` | 想给 AI 加项目特有规则（如"所有 API 必须有 rate limiting"） |
| `init.sh` | 默认检测的安装/测试命令不对你的项目 |

不需要定制：`feature_list.json`、`claude-progress.md`（AI 自己维护）、所有 `.harness/` 内部文件。

### 典型流程

```
你: "我要做一个带用户认证的博客系统"
AI: 读取 CLAUDE.md → 看到 feature_list.json 为空 → 和你讨论需求
    → 拆解成功能列表写入 feature_list.json → 等待你确认

你: "开始工作"
AI: 按功能列表逐个实现 → 每个功能先创建执行计划（.harness/plans/）
    → 按计划写代码 → 跑验证 → 记录进度
    → 遇到 blocker 停下来报告 → 全部完成后生成总结

注意: AI 在编码前会创建执行计划。如果你对计划有意见，在 AI 编码前提出来。
```

## 模板文件

### 框架文件（可自动更新）

| 文件 | 用途 |
|------|------|
| `CLAUDE.md` | Claude Code 根指令文件 |
| `init.sh` | 环境初始化脚本（支持 `health`、`verify` 子命令） |
| `evaluator-rubric.md` | 质量评审评分表 |
| `autonomous-loop.md` | 自治迭代循环协议 |
| `self-eval-trigger.md` | 自我评审触发协议 |

> `AGENTS.md`（Codex 等其他 agent 的指令文件）保留在 `.harness/templates/` 中，不部署到根目录。如需使用，手动复制即可。

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

### 参考文档（`.harness/reference/`）

| 文件 | 内容 |
|------|------|
| [`method-map.md`](./.harness/reference/method-map.md) | 常见失败模式与对应修复工件 |
| [`initializer-agent-playbook.md`](./.harness/reference/initializer-agent-playbook.md) | 初始化阶段操作手册 |
| [`coding-agent-startup-flow.md`](./.harness/reference/coding-agent-startup-flow.md) | 每轮编码会话的固定流程 |
| [`prompt-calibration.md`](./.harness/reference/prompt-calibration.md) | 根指令文件的编写原则 |

## 指令优先级

harness 管项目层面的"做什么"，外部 skill（如 superpowers）管方法论层面的"怎么做"。

| 领域 | 谁负责 | 例子 |
|------|--------|------|
| 功能选择和状态追踪 | **harness** | feature_list.json 状态机 |
| 功能完成标准 | **harness** | evidence required |
| 跨会话连续性 | **harness** | claude-progress.md + events.jsonl |
| 会话开收工流程 | **harness** | hooks 自动执行 |
| 规划方法论 | **外部 skill** | brainstorming → writing-plans |
| 编码方法论 | **外部 skill** | TDD RED-GREEN-REFACTOR |
| 调试方法论 | **外部 skill** | systematic-debugging |
| 代码审查 | **外部 skill** | code-review |

冲突时项目规则优先。详见 CLAUDE.md 中的"指令优先级"部分。

## 设计原则

- **仓库是唯一事实来源** — agent 不依赖聊天记录，所有状态持久化在文件中
- **一次一个功能** — 任何时候只有一个 active feature，避免范围蔓延
- **证据驱动完成** — 功能完成必须跑过验证并记录证据
- **数据永不覆盖** — upgrade 时数据文件（feature_list.json、claude-progress.md）永不触碰
- **定制优先** — 标记为定制的文件不会被自动更新，用户可选择 adopt 接受上游

## 自治迭代

项目内置三层自治循环结构（功能迭代 → 验证修复 → 构建测试），让 agent 在人类下达命令后自动迭代、验证和修复，直到所有功能完成或触发升级条件。

详见 `autonomous-loop.md` 和 `self-eval-trigger.md`。

## Hooks 自动化

初始化后，harness 会自动配置以下强制机制：

| 机制 | 触发时机 | 作用 |
|------|---------|------|
| Claude Code PostToolUse hook | 每次代码修改后 | 检查是否有 in_progress 的功能 |
| Claude Code Stop hook | 会话结束前 | 检查 claude-progress.md 是否已更新 |
| Git pre-commit hook | 每次 git commit 前 | 验证 feature_list.json 和 claude-progress.md 完整性 |

这些机制确保 agent 的行为符合 harness 工作规则，不依赖 prompt 驱动。

## 事件流

hooks 自动向 `.harness/world/events.jsonl` 追加事件记录：

| 事件 | 写入者 | 用途 |
|------|--------|------|
| `session_start` | SessionStart hook | 记录会话开始 |
| `session_end` | Stop hook | 记录会话结束时的功能进度 |
| `feature_status_change` | AI | 功能状态切换 |
| `verification_result` | AI | 验证结果 |

查询事件：`harness query [pattern]`、`harness query --today`、`harness query --since yesterday`

SessionStart hook 会在每次会话开始时输出最近 3 条高价值事件，帮助 AI 更精确地续接上一轮工作。

## 安全注意事项

- `install.sh` 使用 `curl | bash` 安装模式。审查内容后再运行，或直接下载 `bin/harness` 手动安装到 `~/.local/bin/`
- harness CLI 只使用 GitHub 公开 API，不需要 token
- 模板中的 init.sh 使用保守默认值，请审查后再运行
- 所有写操作使用临时文件，确认后再移到目标位置

## 系统要求

- Bash 4+（macOS / Linux / WSL2 / Git Bash）
- curl（用于从 GitHub 拉取模板）
- git（可选，用于版本管理）

## License

MIT
