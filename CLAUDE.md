# CLAUDE.md — HarnessTemplates 开发指南

你正在开发 **HarnessTemplates**——一个 AI coding agent 的长时任务脚手架管理工具。

## 项目概述

这个仓库包含 `harness` CLI 和它分发的模板文件。用户通过 `harness init` 把模板部署到自己的项目中，让 AI agent（Claude Code、Codex 等）获得跨会话的连续性和可验证性。

**双重身份：**
- 这个仓库是 **harness 的源码仓库**（你在开发 harness 本身）
- 用户通过 `install.sh` 安装编译后的 CLI，不直接接触这个仓库

## 代码结构

```
bin/harness                    # CLI 主文件（单文件，~1475 行 bash）
install.sh                     # curl | bash 安装器
.harness/
├── templates/                 # 部署到用户项目的模板文件
│   ├── CLAUDE.md              # 用户项目的 AI 指令（不是这个文件！）
│   ├── AGENTS.md              # 其他 agent 的指令
│   ├── init.sh                # 用户项目的环境初始化脚本
│   ├── feature_list.json      # 功能追踪模板
│   ├── claude-progress.md     # 进度日志模板
│   ├── autonomous-loop.md     # 自治迭代协议
│   ├── self-eval-trigger.md   # 自我评审触发协议
│   ├── evaluator-rubric.md    # 质量评分表
│   ├── plan-template.md       # 执行计划模板
│   ├── history-template.md    # 变更记录模板
│   └── .claude/settings.local.json  # Claude Code hooks 配置
├── scripts/                   # 部署到用户项目的脚本
│   ├── hook-guard.sh          # PostToolUse/Stop hook
│   ├── session-start.sh       # SessionStart hook
│   ├── check-harness.sh       # 结构完整性检查
│   ├── ci.sh                  # CI 串联脚本
│   └── git-pre-commit.sh      # Git pre-commit hook
├── reference/                 # 参考文档（部署到用户项目）
└── config.json                # 运行时配置（不存在于源码仓库）
tests/                         # BATS 测试套件
docs/                          # 设计文档和规划
```

## 开发环境

### 前置条件

- Bash 4+
- [bats-core](https://github.com/bats-core/bats-core)（测试框架）
- curl（测试远程 fetch 功能时需要）

### 安装 bats-core

```bash
# macOS
brew install bats-core

# Linux
npm install -g bats

# 或从源码
git clone https://github.com/bats-core/bats-core.git ~/.local/share/bats
~/.local/share/bats/install.sh ~/.local
```

### 运行测试

```bash
# 运行全部测试
bats tests/

# 运行单个测试文件
bats tests/test_init.bats

# 运行匹配的测试
bats tests/test_*hook*.bats
```

### 本地开发流程

```bash
# 用 --local 标志从本地模板初始化（不用从 GitHub 下载）
cd /tmp/test-project
/path/to/HarnessTemplates/bin/harness init --local

# 验证初始化结果
harness status
harness check
harness doctor
```

## 代码规范

### bin/harness 结构

- **命令函数**：`cmd_<name>()` 命名约定（如 `cmd_init`、`cmd_status`）
- **辅助函数**：下划线前缀（如 `config_read_field`、`fetch_template_to`）
- **分派**：文件末尾的 `case` 语句，函数按命令字母序排列
- **无 jq 依赖**：用 grep/sed/awk 解析 JSON（零依赖分发）

### 约定

- 所有写操作使用临时文件 + mv（原子写入）
- 用户可见的输出使用 `log_info`/`log_success`/`log_warn`/`log_error`
- 配置字段读取用 `config_read_field`/`config_read_array`
- 每个命令开头检查 `.harness/config.json` 是否存在
- 文件分为三类：framework（可自动更新）、data（永不触碰）、scaffold（缺失时补）

### Commit 格式

```
<type>: <description>

Types: feat, fix, refactor, docs, test, chore, perf
```

用英文写 commit message，即使模板内容和 CLI 输出是中文。

## 关键设计决策

1. **单文件 CLI**：为了 `curl | bash` 零依赖分发。有意为之，不要拆分。
2. **不用 jq**：grep/sed/awk 解析 JSON 是为了消除运行时依赖。脆弱但有意。
3. **三层文件分类**：framework/data/scaffold 决定 upgrade 行为。
4. **hooks 而非 prompt**：通过 Claude Code hooks 和 git hooks 机械执行，不靠 prompt 驱动。
5. **模板即源码**：`.harness/templates/` 里的文件就是上游原始副本，upgrade 时作为 diff 基准。

## 常见开发任务

### 添加新命令

1. 在 `bin/harness` 中添加 `cmd_<name>()` 函数
2. 在 `cmd_help()` 中添加说明
3. 在末尾 `case` 语句中添加分派行
4. 在 `tests/` 中添加 `test_<name>.bats`
5. 如果需要新的模板文件，添加到 `.harness/templates/` 和 `cmd_init` 的文件列表中

### 修改模板内容

1. 修改 `.harness/templates/` 中的文件
2. 确保修改不破坏 `tests/test_init.bats` 中的初始化测试
3. 确保 `.harness/reference/index.md` 的文档列表是最新的

### 修改 hooks 行为

1. 修改 `.harness/scripts/` 中的脚本
2. 运行 `bats tests/test_hook_guard.bats tests/test_git_hook.bats`
3. 确保 `.harness/templates/.claude/settings.local.json` 的 hook 配置与脚本匹配
