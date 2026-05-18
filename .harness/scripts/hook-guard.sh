#!/usr/bin/env bash
# .harness/scripts/hook-guard.sh — Claude Code hook guards
set -euo pipefail

case "${1:-}" in
  post-edit)
    if [ ! -f "feature_list.json" ]; then
      exit 0
    fi
    if ! grep -q '"in_progress"' feature_list.json 2>/dev/null; then
      echo "[harness] 没有进行中的功能。请先用 feature_list.json 选一个任务。"
    fi
    # Check for plan file
    if grep -q '"in_progress"' feature_list.json 2>/dev/null; then
      plan_file="$(grep -A10 '"in_progress"' feature_list.json 2>/dev/null | grep -o '"plan_file"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\(.*\)"/\1/' || true)"
      if [ -z "$plan_file" ]; then
        # Check if any plan exists in plans/active
        if [ -d ".harness/plans/active" ] && [ -n "$(find .harness/plans/active -name "*.md" -not -empty 2>/dev/null | head -1)" ]; then
          true  # Plan exists
        else
          echo "[harness] 当前功能没有执行计划。请先用 harness new-plan 创建计划后再编码。"
        fi
      elif [ ! -f "$plan_file" ]; then
        echo "[harness] 计划文件 ${plan_file} 不存在。请先创建计划。"
      fi
    fi
    ;;

  pre-stop)
    if [ ! -f ".harness/.session-start" ] || [ ! -f "claude-progress.md" ]; then
      exit 0
    fi
    session_start="$(stat -f %m .harness/.session-start 2>/dev/null || stat -c %Y .harness/.session-start 2>/dev/null)"
    progress_mtime="$(stat -f %m claude-progress.md 2>/dev/null || stat -c %Y claude-progress.md 2>/dev/null)"
    if [ "$progress_mtime" -le "$session_start" ] 2>/dev/null; then
      echo "[harness] claude-progress.md 未更新。请在结束前记录进度。"
    fi
    ;;

  *)
    echo "Usage: hook-guard.sh {post-edit|pre-stop}" >&2
    exit 1
    ;;
esac
