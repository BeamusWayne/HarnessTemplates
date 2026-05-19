# Design: 项目规则与全局 Skills 的协同

> **Status**: v3 — 聚焦真问题
> **Date**: 2026-05-19

---

## 真问题

harness 是 Claude Code CLI 的约束工具。它通过 CLAUDE.md、hooks、settings.local.json 工作——全部依托 Claude Code 的基础设施。

用户同时装了 superpowers 插件。superpowers 也通过 SessionStart hook 注入指令。两套指令同时生效，AI 不知道听谁的。

这不是存储问题，不是 memory vs skills 的问题，是**指令优先级冲突**。

---

## 冲突清单

| 场景 | superpowers 怎么说 | harness CLAUDE.md 怎么说 | 冲突 |
|------|--------------------|--------------------------|------|
| 规划 | brainstorming skill → enter plan mode → writing-plans skill | harness new-plan 创建计划 | 两个规划流程 |
| 测试 | 严格 RED-GREEN-REFACTOR | "测试验证意图，不仅是行为" | 焦点不同 |
| 完成功能 | verification-before-completion skill | 按 review-checklist.md 自查 | 两套审查流程 |
| 会话收尾 | finishing-a-branch skill | 更新 claude-progress.md | 不同的收尾标准 |
| 代码修改后 | (无 hook) | PostToolUse hook 检查是否有 active feature | 无冲突 |
| 会话开始 | 注入 using-superpowers 指令 | session-start hook 输出项目状态 | 无冲突，但顺序不可控 |

**关键发现**：不是所有场景都冲突。只在"方法论"层面冲突——怎么规划、怎么测试、怎么审查。

---

## 解法：分层分工

```
harness 管"做什么"（项目层）
  → 一次一个功能
  → 完成需要证据
  → 编码前要计划
  → 会话结束要留记录

全局 skills 管"怎么做"（方法论层）
  → 规划用 brainstorming + writing-plans
  → 测试用 TDD RED-GREEN-REFACTOR
  → 调试用 systematic-debugging
  → 审查用 code-review

两者不重叠，只需要明确边界。
```

### 具体分工

| 领域 | 谁负责 | 规则来源 |
|------|--------|----------|
| 功能选择和状态追踪 | **harness** | feature_list.json |
| 功能完成标准 | **harness** | review-checklist.md + evidence |
| 跨会话连续性 | **harness** | claude-progress.md + events.jsonl |
| 会话开收工流程 | **harness** | session-start hook + pre-stop hook |
| 规划方法论 | **全局 skills** | superpowers:brainstorming → writing-plans |
| 编码方法论 | **全局 skills** | superpowers:tdd |
| 调试方法论 | **全局 skills** | superpowers:systematic-debugging |
| 审查方法论 | **全局 skills** | superpowers:requesting-code-review |
| 代码提交策略 | **harness** | 自治模式下的提交规则 |
| git 操作 | **全局 skills** | superpowers:using-git-worktrees 等 |

---

## 实现方案

### 改动 1：CLAUDE.md 模板加优先级声明

在 `.harness/templates/CLAUDE.md` 开头加一段：

```markdown
## 指令优先级

本项目使用 harness 管理功能追踪和项目约束。

当项目规则与外部 skill（superpowers 等）冲突时：
- **harness 负责"做什么"**：功能选择、状态追踪、完成标准、会话交接
- **外部 skill 负责"怎么做"**：规划方法论、TDD、调试、代码审查
- **冲突时项目规则优先**：harness 的约束（一次一个功能、plan-before-code、evidence required）不可被 skill 覆盖
- **规划流程冲突时**：用 superpowers:brainstorming 讨论需求，用 `harness new-plan` 记录计划——两者配合，不二选一
```

### 改动 2：CLAUDE.md 模板移除方法论指令

把当前的编码方法论细节从 CLAUDE.md 移到 reference 文档，CLAUDE.md 只保留约束：

**移除/弱化的内容**：
- "编码前必须规划" → 保留约束"编码前必须有 plan 文件"，但不再规定规划方法论
- "功能完成前必须审查" → 保留约束"功能 passing 前按 review-checklist.md 审查"，但不再规定审查流程
- 三层自治循环的详细步骤 → 移到 autonomous-loop.md（已经在那里了），CLAUDE.md 只引用

**保留的内容**：
- 一次一个功能
- passing 需要证据
- plan-before-code（约束，不是方法论）
- 会话结束更新 claude-progress.md
- token 预算硬约束

### 改动 3：增加 events.jsonl

**唯一的新增结构**。不是 world model，只是事件流。

```
.harness/world/
└── events.jsonl      ← hooks 和 AI 追加事件日志
```

**hooks 自动写入**：
- `session-start.sh`：追加 `session_start` 事件
- `hook-guard.sh pre-stop`：追加 `session_end` 事件

**AI 按需写入**（CLAUDE.md 指令驱动）：
- `feature_status_change`：功能状态切换
- `verification_result`：验证结果

**session-start hook 增加输出**：最近 3 条高价值事件（`feature_status_change`、`verification_result`、`escalation`），让 AI 续接更精确。

**新增 CLI 命令**：
- `harness query <pattern>` — grep events.jsonl

**events.jsonl 被 gitignore**（跟 .harness/ 整体一起）。它是会话级辅助数据，primary 数据在 feature_list.json 和 claude-progress.md。

### 不做的事

- ~~import-skill~~ — 全局 skills 留在全局层面
- ~~procedures/ 目录~~ — 不需要项目级 skill 存储
- ~~world model~~ — 不需要统一存储
- ~~procedure evolution~~ — 过度承诺
- ~~Cognee 集成~~ — harness 依托 Claude Code 基础设施，不重建

---

## 为什么这样就够了

1. **指令冲突是 prompt 问题，不是架构问题**。加一段优先级声明比重建存储系统有效得多。
2. **events.jsonl 是唯一值得新增的结构**。它解决了"跨会话记忆不够精确"的真问题，而且不改变任何现有文件。
3. **harness 的定位是 Claude Code CLI 的约束工具**。它应该在 Claude Code 的框架内工作（CLAUDE.md、hooks、settings），不应该自建框架。
4. **全局 skills 的管理不是 harness 的职责**。superpowers 有自己的生命周期管理。harness 只需要声明"哪些事归我管"。

---

## 迁移步骤

### Phase 1（最小改动）

1. `.harness/templates/CLAUDE.md` 加优先级声明
2. `.harness/templates/CLAUDE.md` 弱化方法论细节
3. `harness init` 和 `harness upgrade` 部署更新后的模板
4. 已有项目：`harness upgrade` 自动更新未定制的 CLAUDE.md

### Phase 2（events.jsonl）

1. `harness init` 创建 `.harness/world/events.jsonl`
2. `session-start.sh` 追加 `session_start` 事件
3. `hook-guard.sh` 追加 `session_end` 事件
4. `session-start.sh` 输出最近 3 条高价值事件
5. 新增 `harness query` 命令

### Phase 3（远期，可选）

1. `harness report` 读取 events.jsonl 生成时间线报告
2. CLAUDE.md 模板增加"状态变更时追加 events.jsonl"的指令
3. 考虑 events 按月轮转
