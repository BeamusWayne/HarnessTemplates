#!/usr/bin/env bash
# .harness/scripts/session-start.sh — Claude Code SessionStart hook
# Outputs project status for AI context. Read-only, never modifies files.
set -euo pipefail

# Fail silently — never block Claude from starting
if [ ! -f "feature_list.json" ]; then
  exit 0
fi

# Extract _status field
get_status() {
  grep -o '"_status"[[:space:]]*:[[:space:]]*"[^"]*"' feature_list.json 2>/dev/null | \
    sed 's/.*:.*"\(.*\)"/\1/' || echo ""
}

# Count features by status
count_status() {
  local status="$1"
  grep -c "\"${status}\"" feature_list.json 2>/dev/null || echo 0
}

project_name="$(basename "$(pwd)")"
_status="$(get_status)"

# Count totals
passing="$(count_status "passing")"
in_progress="$(count_status "in_progress")"
blocked="$(count_status "blocked")"
not_started="$(count_status "not_started")"
total=$((passing + in_progress + blocked + not_started))

if [ "$total" -eq 0 ] || [ "$_status" = "awaiting_requirements" ]; then
  echo "[harness] 项目: ${project_name} | 状态: 待规划"
  echo "[harness] 功能清单为空。告诉 AI 你想做什么项目，AI 会帮你拆解成功能列表。"
else
  # Find first non-passing feature id
  active_id=""
  if [ "$in_progress" -gt 0 ]; then
    active_id="$(grep -B5 '"in_progress"' feature_list.json 2>/dev/null | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\(.*\)"/\1/' || echo "")"
  fi
  if [ -z "$active_id" ] && [ "$not_started" -gt 0 ]; then
    active_id="$(grep -B5 '"not_started"' feature_list.json 2>/dev/null | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\(.*\)"/\1/' || echo "")"
  fi

  status_line="[harness] 项目: ${project_name} | 进度: ${passing}/${total} passing"
  if [ -n "$active_id" ]; then
    status_line="${status_line} | 当前: ${active_id}"
  fi
  echo "$status_line"
  echo "[harness] 建议运行 ./init.sh 同步环境，然后继续当前功能。"
fi
