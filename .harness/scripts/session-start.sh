#!/usr/bin/env bash
# .harness/scripts/session-start.sh — Claude Code SessionStart hook
# Outputs project status for AI context.
set -euo pipefail

# ── Append session_start event
if [ -d ".harness/world" ]; then
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_start\",\"agent\":\"claude-code\"}" \
    >> .harness/world/events.jsonl
fi

# ── Refresh session marker
touch .harness/.session-start 2>/dev/null || true

# ── Auto chmod
chmod +x init.sh .harness/scripts/*.sh 2>/dev/null || true

# Fail silently — never block Claude from starting
if [ ! -f "feature_list.json" ]; then
  exit 0
fi

# Parse the features array ONCE and reuse it. Scoping every lookup to this
# section excludes the status_legend / feature_template / rules blocks, which
# otherwise pollute id/status/reason lookups (e.g. returning the
# feature_template's "feat-NNN" placeholder) — and avoids re-reading the file.
_features_section="$(sed -n '/"features"[[:space:]]*:/,$ p' feature_list.json 2>/dev/null || true)"

# Extract _status field (top-level)
get_status() {
  grep -o '"_status"[[:space:]]*:[[:space:]]*"[^"]*"' feature_list.json 2>/dev/null | \
    sed 's/.*:.*"\(.*\)"/\1/' || echo ""
}

# Count features by status (features array only)
count_status() {
  echo "$_features_section" | grep -c "\"$1\"" 2>/dev/null || true
}

# Extract the first blocked feature's reason (features array only)
get_blocked_reason() {
  echo "$_features_section" | grep -A20 '"blocked"' 2>/dev/null | \
    grep -o '"blocked_reason"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | \
    sed 's/.*:.*"\(.*\)"/\1/' || echo ""
}

# Find the first feature id with the given status. Pairs id<->status per
# feature (tracking the most recent id, emitting it when status matches), so it
# is correct whether each feature is pretty-printed or written on one line.
find_id_by_status() {
  echo "$_features_section" | awk -v want="$1" '
    /"id"[[:space:]]*:/ {
      t=$0; gsub(/.*"id"[[:space:]]*:[[:space:]]*"/,"",t); gsub(/".*/,"",t); id=t
    }
    /"status"[[:space:]]*:/ {
      s=$0; gsub(/.*"status"[[:space:]]*:[[:space:]]*"/,"",s); gsub(/".*/,"",s)
      if (s==want && id!="" && !done) { print id; done=1 }
    }
  '
}

project_name="$(basename "$(pwd)")"
_status="$(get_status)"

# Count totals
passing="$(count_status "passing")"; passing="${passing:-0}"
in_progress="$(count_status "in_progress")"; in_progress="${in_progress:-0}"
blocked="$(count_status "blocked")"; blocked="${blocked:-0}"
not_started="$(count_status "not_started")"; not_started="${not_started:-0}"
total=$((passing + in_progress + blocked + not_started))

if [ "$total" -eq 0 ] || [ "$_status" = "awaiting_requirements" ]; then
  echo "[harness] 项目: ${project_name} | 状态: 待规划"
  echo "[harness] 功能清单为空。告诉 AI 你想做什么项目，AI 会帮你拆解成功能列表。"
else
  # Find active feature
  active_id=""
  if [ "$in_progress" -gt 0 ]; then
    active_id="$(find_id_by_status "in_progress")"
  fi
  if [ -z "$active_id" ] && [ "$not_started" -gt 0 ]; then
    active_id="$(find_id_by_status "not_started")"
  fi

  status_line="[harness] 项目: ${project_name} | 进度: ${passing}/${total} passing"
  if [ -n "$active_id" ]; then
    status_line="${status_line} | 当前: ${active_id}"
  fi
  echo "$status_line"

  # Blocked guidance
  if [ "$blocked" -gt 0 ]; then
    blocked_id="$(find_id_by_status "blocked")"
    blocked_reason="$(get_blocked_reason)"
    echo "[harness] blocked: ${blocked_id} — ${blocked_reason:-原因未记录}"
    echo "[harness] 恢复建议：告诉 AI \"继续 ${blocked_id}\" 或 \"重新规划 ${blocked_id}\""
  else
    echo "[harness] 建议运行 ./init.sh 同步环境，然后继续当前功能。"
  fi

  # Plan file check
  if [ "$in_progress" -gt 0 ] || [ "$not_started" -gt 0 ]; then
    plan_count=0
    if [ -d ".harness/plans/active" ]; then
      plan_count="$(find .harness/plans/active -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
    fi
    pending=$((in_progress + not_started))
    if [ "$plan_count" -eq 0 ] && [ "$pending" -gt 0 ]; then
      echo "[harness] 有 ${pending} 个未完成功能但没有执行计划。编码前必须先用 harness new-plan 创建计划。"
    fi
  fi
fi

# ── Recent events summary (last 3 high-value events)
if [ -f ".harness/world/events.jsonl" ]; then
  recent="$(grep -E '"event":"(feature_status_change|verification_result|escalation)"' .harness/world/events.jsonl 2>/dev/null | tail -3 || true)"
  if [ -n "$recent" ]; then
    echo "[harness] 最近事件:"
    echo "$recent" | while IFS= read -r line; do
      ts="$(echo "$line" | grep -o '"ts":"[^"]*"' | head -1 | sed 's/.*:"\(.*\)"/\1/')"
      evt="$(echo "$line" | grep -o '"event":"[^"]*"' | head -1 | sed 's/.*:"\(.*\)"/\1/')"
      feat="$(echo "$line" | grep -o '"feature":"[^"]*"' | head -1 | sed 's/.*:"\(.*\)"/\1/' || true)"
      result="$(echo "$line" | grep -o '"result":"[^"]*"' | head -1 | sed 's/.*:"\(.*\)"/\1/' || true)"
      msg="  ${ts}  ${evt}"
      [ -n "$feat" ] && msg="${msg}  ${feat}"
      [ -n "$result" ] && msg="${msg} → ${result}"
      echo "$msg"
    done
  fi
fi
