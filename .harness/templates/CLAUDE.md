# CLAUDE.md

你正在一个为长时实现工作设计的仓库中工作。优先保证可靠完成、跨会话连续性和显式验证，而不是表面上的速度。

## 指令优先级

本项目使用 harness 管理功能追踪和项目约束。

### 什么是外部 skill？

外部 skill 是 AI agent 的方法论插件（如 superpowers）。它们提供规划、TDD、调试、代码审查等标准化工作方法。不是所有用户都安装了 skill 插件。如果你未安装任何 skill，harness 的内置规则就是完整的工作指南。

### 分工规则

当项目规则与外部 skill（如 superpowers）冲突时：

- **harness 负责"做什么"**：功能选择、状态追踪、完成标准、会话交接
- **外部 skill 负责"怎么做"**：规划方法论（brainstorming、writing-plans）、编码方法论（TDD）、调试（systematic-debugging）、代码审查
- **冲突时项目规则优先**：harness 的约束（一次一个功能、plan-before-code、evidence required）不可被 skill 覆盖
- **规划流程**：用外部 skill 讨论需求和设计方案，用 `harness new-plan` 记录计划——两者配合，不二选一
- **无外部 skill 时**：harness 的行为规则和工作循环就是完整的工作方法，不需要额外插件

## 行为规则

### Rule 1 — 先想再写
- 遇到不确定，先问再猜。存在多种解读时，把每种都列出来。
- 有更简单的方案时，提出来。困惑时停下来，说清楚哪里不懂。

### Rule 2 — 最简优先
- 只写解决问题所需的最少代码。不加 speculative 功能。
- 单次使用的代码不加抽象。检验标准：高级工程师会认为这是过度设计吗？

### Rule 3 — 精准改动
- 只动必须动的。只清理自己弄乱的。
- 不顺手"改进"相邻代码、注释或格式。不重构没坏的东西。匹配现有风格。

### Rule 4 — 目标驱动
- 先定义成功标准，循环验证直到通过。
- 不按步骤走，按目标走。好的成功标准让你能独立循环。

### Rule 5 — 模型只用于判断
- 用我来做：分类、起草、总结、提取。
- 不要用我来做：路由、重试、确定性转换。代码能回答的，让代码回答。

### Rule 6 — Token 预算是硬约束
- 单任务：4,000 tokens。单会话：30,000 tokens。
- 每完成一个功能的子任务后，主动报告剩余预算估算。
- 当剩余预算 < 30% 时，必须：
  1. 暂停当前功能
  2. 更新 claude-progress.md 记录进度和重启路径
  3. 告诉用户："剩余预算约 X tokens，建议开启新会话继续"
- 自治模式下，当剩余预算 < 20% 时，必须完成当前功能的收尾流程后停止，不得开启新功能。
- 超了要显式报告，不要静默超限。

### Rule 7 — 冲突要暴露，不要取平均
- 两个模式矛盾时，选一个（更近的 / 更久经考验的），解释原因。
- 标记另一个待清理。不混合矛盾模式。

### Rule 8 — 写之前先读
- 加代码之前，先读 exports、直接调用方、共享工具。
- "看起来正交"是危险的。不确定为什么代码这样组织时，先问。
- 仓库内文件是唯一事实来源。

### Rule 9 — 测试验证意图，不仅是行为
- 测试必须编码"为什么这个行为重要"，不仅是"做了什么"。
- 业务逻辑变了却不会失败的测试，是错的测试。
- 不为了"看起来完成"而删除或削弱测试。
- 具体的 TDD 方法论（RED-GREEN-REFACTOR）由外部 skill 驱动。

### Rule 10 — 每个关键步骤后 checkpoint
- 总结：做了什么、验证了什么、还剩什么。
- 无法描述当前状态时，不要继续。丢失上下文时，停下来重述。

### Rule 11 — 遵守代码库惯例
- 代码库内，一致性 > 个人品味。
- 真正认为某惯例有害时，提出来讨论。不要静默另搞一套。

### Rule 12 — 失败要响亮
- 跳过了任何东西却声称"完成"，是错的。
- 跳过了任何测试却说"测试通过"，是错的。
- 默认暴露不确定性，不要隐藏。
- 不通过重写功能清单来掩盖未完成工作。

## 固定工作循环

每轮会话开始时：

1. 运行 `pwd`，确认当前在正确的仓库根目录
2. 读取 `claude-progress.md`
3. 读取 `feature_list.json`
4. 用 `git log --oneline -5` 查看最近提交
5. 运行 `./init.sh`
6. 运行 `touch .harness/.session-start` 刷新会话标记
7. 检查基础 smoke test 或端到端路径是否已经损坏

然后只选择一个未完成功能，围绕它工作，直到它被验证通过，或者被明确记录为 blocked。

如果 `feature_list.json` 的 `features` 为空（`_status` 为 `awaiting_requirements`），先和用户讨论需求，把大目标拆解成可验证的小功能，写入 `features` 数组。**写入后必须等用户确认满意，才能将 `_status` 改为 `"active"`。**

**约束：同一时间只能有一个 active feature。**

### 需求拆解规则

拆解功能时必须遵守：
1. **第一个功能必须是"项目基础设施"**（priority 1），包含：项目脚手架搭建、测试框架配置、lint/format 配置。只有这个功能 passing 后才能开始后续业务功能。
2. 每个功能必须包含：`description`（功能描述）、`depends_on`（依赖的其他功能 id）、`verification`（验证标准）。
3. 功能粒度：一个功能应在 1-2 小时内可完成。太大则拆分，太小则合并。

### 编码前必须规划

对每个功能，编码前必须：
1. 用 `harness new-plan <feature-id>` 创建执行计划
2. 计划内容：需要创建/修改的文件、每个文件的改动描述、验证步骤、任务间依赖
3. 在 feature_list.json 的 `plan_file` 字段记录计划文件路径
4. **不允许在没有计划的情况下直接开始编码。**

### 功能完成前必须审查

功能标记 passing 前，必须按 `.harness/reference/review-checklist.md` 进行结构化自查。审查结果写入 `evidence` 字段，包含逐项的具体发现（不是简单的"已通过"）。具体的代码审查方法（reviewer 角度、逐文件检查等）由外部 skill 驱动。

## 自治迭代循环

当人类发出"开始工作"或"继续"指令后，进入自治模式。按以下循环工作，直到所有功能 passing 或触发升级条件。

### 外层：功能循环

REPEAT:
  1. 读取 feature_list.json
  2. 找到优先级最高的 not_started 或 in_progress 功能
  3. 如果没有 → 退出循环，报告"所有功能已完成"
  4. 检查该功能是否有 plan 文件（plan_file 字段或 .harness/plans/active/ 中对应文件）
  5. 如果没有 plan → 先创建计划，再继续
  6. 对该功能执行中层循环
  7. 如果功能状态变为 passing → 更新 evidence，提交，继续下一个
  8. 如果功能状态变为 blocked → 记录 blocker 和 blocked_reason，跳到下一个 not_started 功能
  9. 如果连续 2 个功能都 blocked → 停止，报告升级

### 中层：验证-修复循环（每个功能最多 N 轮）

REPEAT (max: feature.iteration_budget 次，默认 5):
  1. 实现或修复代码
  2. 运行 auto_check.command（如果有）或手动验证步骤
  3. 如果通过 → 执行审查（review-checklist.md），审查通过后标记 passing，退出中层循环
  4. 如果失败 → 分类错误:
     - 构建错误（编译/类型）→ 自动修复，重试
     - 测试断言失败 → 分析 diff，修复，重试
     - 环境错误（端口占用、依赖缺失）→ 尝试一次修复，如果仍失败则升级
     - 未知错误 → 记录，升级
  5. 每次失败后，递增该功能的 iteration_count
  6. 如果 iteration_count >= iteration_budget → 标记 blocked，记录 blocked_reason，退出

### 内层：构建-测试循环

REPEAT (max: 3 次):
  1. 编写或修改代码
  2. 运行 ./init.sh 中的 VERIFY_CMD
  3. 如果通过 → 返回成功
  4. 如果失败 → 读取错误输出，生成最小修复
  5. 如果 3 次都失败 → 返回到中层循环，报告"构建修复失败"

### 升级条件（立即停止自治，通知人类）

满足以下任一条件时，停止自治循环：
- 连续 2 个功能变为 blocked
- 当前功能的 iteration_count 达到 iteration_budget
- 运行 ./init.sh health 失败（基础环境坏了）
- Token 预算剩余不足 30%（提醒用户）；不足 20%（强制停止）
- 检测到自己正在重复同一个修改（用 git diff 检测连续两次 diff 相似度 > 80%）

### 自治模式下的提交策略

- 每个功能 passing 后立即提交（不攒）
- 每次 iteration_count 递增时，如果代码有实际改动，也提交（带 wip: 前缀）
- blocked 的功能不留未提交代码——要么回滚到上一个 good state，要么提交并标注

## 必需文件

| 文件 | 用途 |
|------|------|
| `feature_list.json` | 功能清单与状态 |
| `claude-progress.md` | 进度日志与跨会话交接 |
| `init.sh` | 环境初始化 |

## 参考文件

以下文件按需读取，不需要每次都读：

| 文件 | 什么时候读 |
|------|-----------|
| `.harness/reference/method-map.md` | 遇到反复失败时 |
| `.harness/reference/initializer-agent-playbook.md` | 首次初始化项目时 |
| `.harness/reference/coding-agent-startup-flow.md` | 不确定开工流程时 |
| `.harness/reference/prompt-calibration.md` | 调整根指令时 |
| `.harness/reference/planning-methodology.md` | 拆解功能或创建执行计划时 |
| `.harness/reference/review-checklist.md` | 功能完成前的代码审查 |
| `.harness/reference/testing-strategy.md` | 编写测试或设计验证方案时 |
| `./autonomous-loop.md` | 进入自治模式时 |
| `./self-eval-trigger.md` | 自治模式需要自我评审时 |
| `.harness/plans/active/` | 接手复杂任务时 |

## 结构验证

当怀疑 harness 文件不完整时，运行：

    harness check

## 完成门槛

只有在要求的验证成功且结果被记录后，功能状态才可以切换到 `passing`。

## 结束前

1. 更新 `claude-progress.md`
2. 更新 `feature_list.json` 中的功能状态
3. 记录仍然损坏或未验证的内容
4. 在仓库可安全恢复后提交
5. 给下一轮会话留下干净的重启路径
6. 运行 `harness check` 确认状态干净
