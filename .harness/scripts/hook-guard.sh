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
          # Check if any plan is filled (not just template placeholders)
          local any_filled=false
          for pf in .harness/plans/active/*.md; do
            [ -f "$pf" ] || continue
            if ! grep -qE '<任务标题>|<第一步>|<待' "$pf" 2>/dev/null; then
              any_filled=true
              break
            fi
          done
          if [ "$any_filled" = false ]; then
            echo "[harness] 所有计划文件仍是空模板。请先填充具体内容后再编码。"
          fi
        else
          echo "[harness] 当前功能没有执行计划。请先用 harness new-plan 创建计划后再编码。"
        fi
      elif [ ! -f "$plan_file" ]; then
        echo "[harness] 计划文件 ${plan_file} 不存在。请先创建计划。"
      elif grep -qE '<任务标题>|<第一步>|<第一步>|<待' "$plan_file" 2>/dev/null; then
        echo "[harness] 计划文件仍是空模板。请先填充具体内容后再编码。"
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
    # Append session_end event
    if [ -d ".harness/world" ] && [ -f "feature_list.json" ]; then
      _features_section="$(sed -n '/"features"[[:space:]]*:/,$ p' feature_list.json 2>/dev/null || true)"
      passing="$(echo "$_features_section" | grep -c '"passing"' 2>/dev/null || true)"
      passing="${passing:-0}"
      remaining="$(echo "$_features_section" | grep -cE '"(not_started|in_progress|blocked)"' 2>/dev/null || true)"
      remaining="${remaining:-0}"
      echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_end\",\"features_completed\":${passing},\"features_remaining\":${remaining}}" \
        >> .harness/world/events.jsonl
    fi
    ;;

  *)
    echo "Usage: hook-guard.sh {post-edit|pre-stop}" >&2
    exit 1
    ;;
esac
