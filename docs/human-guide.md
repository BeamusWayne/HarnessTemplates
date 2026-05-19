# Harness 人类操作手册

> 这个文件是写给你的（人类）。其他 harness 文件（CLAUDE.md、autonomous-loop.md 等）是写给 AI 的，你不需要读。

## 你需要做什么

### 安装

```bash
curl -fsSL https://raw.githubusercontent.com/BeamusWayne/HarnessTemplates/main/install.sh | bash
```

不安心用 curl | bash？直接下载 `bin/harness` 放到 `~/.local/bin/` 也行。

### 初始化项目

```bash
cd your-project
harness init
```

初始化会在项目里生成一堆文件。你只需要关心这几个：

| 你需要关心的 | 不用管的 |
|-------------|---------|
| `feature_list.json` — 功能清单 | `CLAUDE.md` — AI 的行为规则 |
| `claude-progress.md` — 进度日志 | `AGENTS.md` — 其他 agent 的规则 |
| | `autonomous-loop.md` — 自治协议 |
| | `evaluator-rubric.md` — 评分表 |
| | `self-eval-trigger.md` — 自评触发 |
| | `.harness/` — 全部内部文件 |

### 日常流程

```
1. 打开 Claude Code
2. 告诉 AI 你想做什么
3. AI 拆解成功能列表 → 你确认
4. 说"开始工作" → AI 自动干活
5. 需要你介入时 AI 会停下来告诉你
```

### 每次会话

**开始时**：AI 会自动读取上次的进度。你不需要做任何事。

**结束时**：AI 会自动更新 `claude-progress.md`。如果你想看进度：

```bash
harness status     # 功能进度概览
```

### 你需要介入的时刻

| 什么时候 | 怎么做 |
|---------|--------|
| AI 让你确认功能列表 | 看一遍 `feature_list.json`，满意就说"确认" |
| AI 报告 blocked | 看原因，解决后说"继续 feat-XXX"或"重新规划 feat-XXX" |
| AI 报告升级（连续 blocked） | 需要你人工判断方向 |
| AI 报告 token 预算不足 | 开一个新会话，AI 会自动接上 |

### 功能状态含义

```
not_started  — 还没碰
in_progress  — 正在做（同一时间只有一个）
blocked      — 卡住了，需要你介入
passing      — 做完了，验证通过
```

### 功能被 blocked 了怎么办

1. AI 会告诉你原因（比如"缺少 OAuth 配置"）
2. 你有两个选择：
   - 解决阻塞问题，然后说"继续 feat-XXX"
   - 跳过它，说"先做下一个功能"——AI 会选优先级最高的未完成功能
3. 如果连续 2 个功能都 blocked，AI 会停下来等你决策

### 常用命令

```bash
harness status              # 查看功能进度
harness query --today       # 今天的事件日志（会话开始/结束、状态变更）
harness doctor              # 诊断问题（文件缺失、版本过旧等）
harness upgrade             # 更新模板到最新版本
harness customize CLAUDE.md # 标记文件为已定制（upgrade 时不覆盖）
```

### 定制

默认模板对大多数项目够用。你可能需要定制的：

| 文件 | 什么时候定制 |
|------|------------|
| `CLAUDE.md` | 想给 AI 加项目特有的规则（比如"所有 API 必须有 rate limiting"） |
| `init.sh` | 默认检测的安装/测试命令不对你的项目 |

定制方法：
```bash
harness customize CLAUDE.md   # 标记为已定制
# 然后编辑 CLAUDE.md
# 之后 harness upgrade 不会覆盖它
```

不需要定制的：`feature_list.json`、`claude-progress.md`（AI 自己维护）、所有 `.harness/` 内部文件。

### 关于外部 Skill 插件

如果你安装了 superpowers 等外部 skill 插件，它们会提供规划、TDD、调试等方法论。harness 不管"怎么做"，只管"做什么"。两者不冲突——harness 负责功能追踪，skill 负责工作方法。

如果你没装任何 skill 插件，忽略这段话就行。harness 本身就够了。

### 遇到问题

```bash
harness doctor     # 诊断：文件缺失、版本不一致、hook 状态
harness check      # 结构完整性检查（加 --fix 自动修复）
```
