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
