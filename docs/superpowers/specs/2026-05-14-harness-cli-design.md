# HarnessTemplates CLI 工具设计规格书

> 目标：实现"一次导入, 终身复用, 自动更新"——用户一行命令初始化，模板框架自动更新，项目数据永不丢失。
> 日期：2026-05-14

---

## 1. 概述

### 1.1 问题陈述

当前 HarnessTemplates 是一组静态模板文件，用户需要手动复制到项目中。存在的问题：

- **导入繁琐**：手动复制 9+ 文件，逐个修改路径和命令
- **无法更新**：模板改进后，已导入的项目无法同步新版本
- **数据风险**：更新时可能覆盖用户的项目特定数据（feature_list.json 等）
- **无状态管理**：不知道当前用的是哪个版本，不知道哪些文件被定制过

### 1.2 解决方案

提供一个 `harness` CLI 工具（纯 bash），实现：

1. **一行命令初始化**：`harness init` 自动生成所有文件
2. **智能更新**：`harness upgrade` 自动更新框架文件，交互式处理定制文件，永不触碰数据文件
3. **状态可视化**：`harness status` 显示版本、功能进度、定制情况

### 1.3 设计决策记录

| 决策 | 选项 | 选择 | 理由 |
|------|------|------|------|
| CLI 实现方式 | 纯 bash / npm / Python | 纯 bash | 零依赖，开发者友好 |
| 更新策略 | 严格覆盖 / 白名单 / 差异交互 | 差异交互（默认）+ `--auto` 跳过 | 用户选择偏好交互，同时保留自动化选项 |
| 架构 | 单脚本 / 模块化 / 混合 | 混合（单文件函数模块化） | 分发简单，后期可拆分 |
| 跨平台 | bash only / bash+PowerShell / Node.js | bash only + 环境检测 | Claude Code/Codex 用户已有 bash 环境 |
| 命令数量 | 6 核心 / 8 含定制 / 12 完整 | 12 完整 | 用户明确要求 |
| 文件精简 | 保留全部 / 合并部分 | 合并：去掉 3 个，新增 3 个 | 减少维护负担，功能由 CLI 覆盖 |

---

## 2. 架构

### 2.1 仓库结构

```
HarnessTemplates/
├── bin/
│   └── harness                     # CLI 工具（单文件，函数模块化，~800 行）
├── install.sh                       # 安装器：curl | bash
├── .harness/
│   ├── templates/                   # 框架模板（用户导入的源头）
│   │   ├── CLAUDE.md
│   │   ├── AGENTS.md
│   │   ├── init.sh
│   │   ├── feature_list.json
│   │   ├── claude-progress.md
│   │   ├── evaluator-rubric.md
│   │   ├── autonomous-loop.md       # 新增
│   │   ├── self-eval-trigger.md     # 新增
│   │   ├── plan-template.md         # 新增
│   │   ├── history-template.md      # 新增
│   │   └── index.md
│   ├── reference/                   # 参考文档（不变）
│   │   ├── method-map.md
│   │   ├── initializer-agent-playbook.md
│   │   ├── coding-agent-startup-flow.md
│   │   ├── prompt-calibration.md
│   │   └── index.md
│   └── scripts/                     # 验证脚本
│       ├── check-harness.sh
│       └── ci.sh
├── README.md
└── LICENSE
```

### 2.2 用户项目结构

```
用户项目/
├── CLAUDE.md                  # 框架文件（可定制）
├── AGENTS.md                  # 框架文件（可定制）
├── init.sh                    # 框架文件（可定制）
├── evaluator-rubric.md        # 框架文件
├── autonomous-loop.md         # 框架文件
├── self-eval-trigger.md       # 框架文件
├── feature_list.json          # 数据文件（永不自动更新）
├── claude-progress.md         # 数据文件（永不自动更新）
├── .harness/
│   ├── config.json            # CLI 管理配置
│   ├── templates/             # 上游模板原始副本（用于 diff）
│   ├── scripts/               # 验证脚本
│   ├── plans/
│   │   ├── active/
│   │   └── completed/
│   └── histories/
│       └── YYYY-MM/
└── src/                       # 用户的应用代码
```

### 2.3 模板文件三分类

| 分类 | 文件 | upgrade 行为 |
|------|------|-------------|
| **框架文件** | CLAUDE.md, AGENTS.md, init.sh, evaluator-rubric.md, autonomous-loop.md, self-eval-trigger.md | 可自动更新；被定制则进入交互模式 |
| **数据文件** | feature_list.json, claude-progress.md | 永不自动更新 |
| **脚手架文件** | plan-template.md, history-template.md | 自动添加（如果不存在） |

### 2.4 去掉的文件及理由

| 去掉的文件 | 理由 | 替代方案 |
|-----------|------|---------|
| `session-handoff.md` | 与 claude-progress.md 功能重叠 | 合并到 claude-progress.md |
| `clean-state-checklist.md` | 手动清单可被自动化替代 | `harness check` 命令覆盖所有检查项 |
| `quality-document.md` | 与 evaluator-rubric.md 功能重叠 | 合并到 evaluator-rubric.md |

### 2.5 CLI 与 init.sh 的分工

| 功能 | 谁负责 | 理由 |
|------|--------|------|
| 安装/初始化/升级 harness | `harness` CLI | 框架管理，不是项目运行 |
| 项目环境初始化 | `init.sh` | 项目级别，每个项目不同 |
| 结构检查 | `harness check` | 串联 check-harness.sh |
| 环境健康检查 | `init.sh health` | 项目级别 |
| 创建计划/历史 | `harness new-plan/new-history` | 框架管理功能 |

init.sh 保留子命令：`(default)`, `health`, `verify`

---

## 3. CLI 命令设计

### 3.1 安装

```bash
curl -fsSL https://raw.githubusercontent.com/BeamusWayne/HarnessTemplates/main/install.sh | bash
```

install.sh 做的事：
1. 检测平台（需要 bash 环境：macOS / Linux / WSL2 / Git Bash）
2. 检测到不支持的环境（原生 Windows cmd/PowerShell）时，给出明确提示
3. 下载 `bin/harness` 到 `~/.local/bin/`
4. 确保 `~/.local/bin/` 在 PATH 中
5. 输出版本信息确认安装成功

### 3.2 12 个命令

#### 3.2.1 `harness init`

在当前项目中初始化 harness。

流程：
1. 检测当前目录是否已有 `.harness/config.json`（避免重复初始化）
2. 检测已有文件是否会被覆盖（提示用户确认）
3. 从 GitHub 拉取最新模板到临时目录
4. 框架文件复制到项目根目录
5. 数据文件生成空模板
6. 脚手架文件复制到 `.harness/templates/`
7. 验证脚本复制到 `.harness/scripts/`
8. 创建 `.harness/plans/active/`、`.harness/plans/completed/`、`.harness/histories/` 目录
9. 生成 `.harness/config.json`
10. 运行 `harness check` 验证安装完整性

生成的 `.harness/config.json`：
```json
{
  "harness_version": "2.0.0",
  "initialized_at": "2026-05-14T10:30:00Z",
  "project_name": "",
  "customized_files": [],
  "file_categories": {
    "framework": [
      "CLAUDE.md", "AGENTS.md", "init.sh",
      "evaluator-rubric.md",
      "autonomous-loop.md", "self-eval-trigger.md"
    ],
    "data": [
      "feature_list.json", "claude-progress.md"
    ],
    "scaffold": [
      "plan-template.md", "history-template.md"
    ]
  },
  "upstream": {
    "repo": "BeamusWayne/HarnessTemplates",
    "branch": "main"
  }
}
```

#### 3.2.2 `harness upgrade`

拉取上游更新，智能合并。

参数：
- `--auto` — 跳过交互，自动更新未定制文件，跳过定制文件
- `--dry-run` — 只显示将要做什么，不实际执行

流程：
1. 读取 `.harness/config.json` → 获取当前版本和上游 repo
2. 从 GitHub API 获取最新 tag（或 main 分支最新 commit）
3. 如果已是最新 → 输出提示并退出
4. 拉取最新模板到临时目录
5. 遍历框架文件：
   - 未定制 → 自动覆盖项目文件 + 更新 `.harness/templates/` 副本
   - 已定制 → 对比 `.harness/templates/` 副本 vs 新版本
     - 有差异：显示 diff，交互选择
       - `[a]` 采用上游版本（覆盖 + 更新副本 + 移除定制标记）
       - `[k]` 保留本地版本（不更新，保持定制标记）
       - `[e]` 打开编辑器手动合并（更新副本为新版本，项目文件不动）
       - `[s]` 跳过
     - 无差异：不需要操作
6. 检查新增文件（直接添加）
7. 检查删除文件（输出警告，不自动删除）
8. 更新 `.harness/config.json` 的 `harness_version`
9. 运行 `harness check` 验证完整性
10. 输出更新报告

#### 3.2.3 `harness status`

显示当前状态。

输出：
```
项目: my-project
框架版本: v2.0.0 (最新)
上次更新: 2026-05-14

功能进度: 3 passing / 1 in_progress / 5 not_started / 9 total
定制文件: CLAUDE.md, init.sh (2 个)
```

#### 3.2.4 `harness check`

运行结构完整性检查。

检查项：
- 必需文件是否存在
- feature_list.json 是否为合法 JSON
- init.sh 是否有执行权限
- .harness/config.json 是否存在且格式正确
- 没有文件包含 CRLF 换行符（可选 `--fix` 自动修复）
- 没有长期处于 in_progress 的功能（超过 24 小时）

参数：
- `--fix` — 自动修复可修复的问题（CRLF、权限）

#### 3.2.5 `harness diff <file>`

对比项目文件与 `.harness/templates/` 中的原始副本。

输出标准 unified diff 格式。

#### 3.2.6 `harness adopt <file>`

放弃本地修改，接受上游版本（用 `.harness/templates/` 的原始副本覆盖项目文件）。

同时从 `customized_files` 中移除该文件。

#### 3.2.7 `harness customize <file>`

标记文件为"已定制"，加入 `config.customized_files`。后续 upgrade 不会自动更新此文件。

#### 3.2.8 `harness uncustomize <file>`

取消定制标记，从 `config.customized_files` 移除。下次 upgrade 会自动更新此文件。

#### 3.2.9 `harness new-plan <name>`

从 `plan-template.md` 生成执行计划到 `.harness/plans/active/`。

文件名格式：`YYYYMMDD-HHmm-<name>.md`

#### 3.2.10 `harness new-history <name>`

从 `history-template.md` 生成变更记录到 `.harness/histories/YYYY-MM/`。

文件名格式：`YYYYMMDD-HHmm-<name>.md`

#### 3.2.11 `harness report`

读取 `feature_list.json` 和 `.harness/histories/` 生成结构化工作总结。

输出包含：功能进度、已完成功能列表（含证据）、当前进行中功能、变更历史统计、自治效率指标（如有）。

#### 3.2.12 `harness doctor`

诊断 harness 问题。

检查项：
- 版本是否过旧
- 文件是否缺失
- config.json 格式是否正确
- 定制文件是否有待处理的更新
- 是否有冲突状态（如在 in_progress 超过 24 小时的功能）

---

## 4. 版本管理

### 4.1 版本号规则

使用 Git tag，遵循语义化版本：

- `v1.x.x` — 初始模板（当前状态）
- `v2.0.0` — CLI 工具引入 + 文件精简
- `v2.1.0` — 新增命令或模板文件
- `v2.0.1` — bug 修复

### 4.2 版本获取方式

优先使用 GitHub tags API，备选 main 分支最新 commit SHA。

### 4.3 配置文件版本迁移

如果 `config.json` 格式在不同版本间有变化，`harness doctor` 负责自动迁移到最新格式。

---

## 5. 两份修改意见书的整合

### 5.1 自治迭代意见书整合

| 原建议 | 整合方式 |
|--------|---------|
| 三层循环结构 | 新文件 `autonomous-loop.md` |
| `auto_check` 字段 | 更新 `feature_list.json` 模板结构 |
| `autonomous_config` | 更新 `feature_list.json` 顶层配置 |
| 自我评审触发 | 新文件 `self-eval-trigger.md` |
| CLAUDE.md 自治章节 | 更新 `CLAUDE.md` 模板 |
| AGENTS.md 自治工作模式 | 更新 `AGENTS.md` 模板 |
| init.sh 健康检查 | 更新 `init.sh` 模板（子命令 health） |
| 进度记录迭代表 | 更新 `claude-progress.md` 模板 |
| evaluator-rubric 通过线 | 更新 `evaluator-rubric.md` 模板 |

### 5.2 iFurySt 意见书整合

| 原建议 | 整合方式 |
|--------|---------|
| check-harness.sh | `.harness/scripts/check-harness.sh`，被 `harness check` 调用 |
| ci.sh | `.harness/scripts/ci.sh` |
| 执行计划系统 | `plan-template.md` + `harness new-plan` |
| 变更历史归档 | `history-template.md` + `harness new-history` |
| init.sh 子命令 | 更新 `init.sh` 模板 |
| 进度记录拆分 | `claude-progress.md` 精简为索引头 |
| CLAUDE.md 参考文件引用 | 更新 `CLAUDE.md` 模板 |

---

## 6. 错误处理

| 场景 | 处理方式 |
|------|---------|
| 无网络连接 | upgrade 输出错误提示并退出；不影响本地命令 |
| GitHub API 限流 | 使用 conditional request 减少调用；被限流时 fallback 到 git clone |
| 项目已有同名文件 | init 在覆盖前提示确认 |
| config.json 损坏 | doctor 检测并修复 |
| 用户中断（Ctrl+C） | 写操作使用临时文件，确认后再移到目标位置 |
| 权限不足 | install.sh 检查写权限，提示解决方案 |
| 上游删除了文件 | upgrade 输出警告，不自动删除 |
| 版本格式变化 | doctor 自动迁移 config.json |

---

## 7. 安全考虑

| 风险 | 缓解 |
|------|------|
| curl \| bash 供应链攻击 | README 中说明安全注意事项；未来可加 checksum 验证 |
| GitHub API token 泄露 | 不使用 token，只用公开 API |
| 模板中的恶意命令 | init.sh 使用保守默认值；用户审查后再运行 |

---

## 8. 实施路线图

| 阶段 | 内容 | 预计产出 |
|------|------|---------|
| Phase 1 | bin/harness 骨架 + install.sh + init/status/version/check | 可安装、可初始化 |
| Phase 2 | upgrade/diff/adopt/customize/uncustomize | 完整版本管理 |
| Phase 3 | new-plan/new-history/report/doctor | 完整 12 命令 |
| Phase 4 | 整合两份意见书——更新所有模板文件 | 自治迭代 + 结构优化 |
| Phase 5 | 文档（README、使用指南、架构说明） | 可发布 |

---

## 9. 跨平台策略

第一版：纯 bash，明确声明需要 bash 环境（macOS / Linux / WSL2 / Git Bash）。

兼容性措施：
- 避免使用 macOS 专属命令语法（如 BSD sed -i ''）
- install.sh 检测环境，不支持的环境给出清晰提示
- 未来可选：npm 包包装，简化 Windows 用户安装
