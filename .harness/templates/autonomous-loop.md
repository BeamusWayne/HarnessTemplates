# 自治循环协议

本文件定义自治模式的触发、循环、退出和升级规则。

## 触发

当人类指令包含"自治关键词"或显式指定 autonomous_config.enabled: true 且发送了工作指令时，进入自治模式。

## 循环

WHILE 还有未完成功能 AND 未触发升级条件:
  feature <- 下一个最高优先级 not_started 功能
  feature.status <- in_progress
  iteration_count <- 0

  WHILE iteration_count < autonomous_config.max_iterations_per_feature:
    iteration_count++
    implement_or_fix(feature)
    result <- run_verification(feature)

    IF result == PASS:
      feature.status <- passing
      feature.evidence <- result.output
      commit("feat: " + feature.title)
      BREAK  // 跳出内层循环，进入下一个功能

    ELSE:
      error_class <- classify_error(result)
      IF error_class == BUILD_ERROR:
        auto_fix_build(result.error_output)
        CONTINUE
      ELIF error_class == TEST_FAILURE:
        auto_fix_test(result.error_output)
        CONTINUE
      ELIF error_class == ENV_ERROR:
        IF attempt_env_fix_once():
          CONTINUE
        ELSE:
          feature.status <- blocked
          BREAK  // 跳出内层，尝试下一个功能
      ELSE:  // UNKNOWN
        feature.status <- blocked
        record_blocker(feature, result.error_output)
        BREAK

  IF iteration_count >= max_iterations:
    feature.status <- blocked
    record_blocker(feature, "达到最大迭代次数")

  consecutive_blocked_count <- count_recent_blocked()
  IF consecutive_blocked_count >= autonomous_config.max_consecutive_blocked:
    ESCALATE("连续 N 个功能被阻塞")

ESCALATE_IF_TOKEN_LOW(autonomous_config.stop_on_budget_remaining_percent)

// 所有功能处理完毕
REPORT_SUMMARY()

## 退出条件

1. 所有功能 passing -> 输出完成报告
2. 升级条件触发 -> 输出升级报告，等待人类
3. Token 预算不足 -> 完成当前功能收尾后停止

## 升级条件

| 条件 | 动作 |
|------|------|
| 连续 >= N 个功能 blocked | 停止，报告阻塞原因 |
| 单个功能达到最大迭代次数 | 标记 blocked，尝试下一个功能 |
| ./init.sh health 失败 | 立即停止，报告环境问题 |
| Token 预算 < 20% | 完成当前功能收尾，停止 |
| 连续 2 次提交 diff 相似度 > 80% | 停止，报告疑似死循环 |
| 任何修改导致之前 passing 的功能失败 | 立即回滚该修改，标记当前 blocked |

## 循环重复检测

每次准备提交前，对比本次修改的 diff 与上一次提交的 diff：
- 如果两个 diff 的行级相似度 > 80%，说明 agent 在重复同一个修改
- 记录日志，触发升级

## 回滚保护

自治模式下，如果某个修改导致之前已 passing 的功能回归失败：
1. 立即 git stash 或 git checkout -- . 回滚
2. 将当前功能标记为 blocked，记录原因："修改导致 feature-XXX 回归"
3. 不再尝试修复该功能，跳到下一个

## 输出报告模板

## 自治工作总结

**模式：** 自治迭代
**开始时间：** YYYY-MM-DD HH:MM
**结束时间：** YYYY-MM-DD HH:MM
**总时长：** X 分钟

### 结果统计
- 总功能数：M
- 完成并 passing：N
- 被阻塞（blocked）：K
- 未开始：M - N - K

### 已完成功能
| ID | 标题 | 迭代次数 | 证据 |
|----|------|---------|------|

### 被阻塞功能
| ID | 标题 | 阻塞原因 | 已尝试次数 |
|----|------|---------|-----------|

### 需要人工处理
1. [具体描述第一个需要人类介入的事项]
2. [具体描述第二个]

### 提交记录
- hash1 feat: XXX
- hash2 fix: YYY
