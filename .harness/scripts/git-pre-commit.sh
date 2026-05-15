#!/usr/bin/env bash
# managed by harness — do not edit manually
set -euo pipefail

errors=0

if [ -f "feature_list.json" ]; then
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 -c "import json,sys; json.load(open('feature_list.json'))" 2>/dev/null; then
      echo "[harness] feature_list.json 不是合法 JSON" >&2
      errors=$((errors + 1))
    fi
  elif command -v node >/dev/null 2>&1; then
    if ! node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8'))" 2>/dev/null; then
      echo "[harness] feature_list.json 不是合法 JSON" >&2
      errors=$((errors + 1))
    fi
  fi
else
  echo "[harness] feature_list.json 不存在" >&2
  errors=$((errors + 1))
fi

if [ -f "claude-progress.md" ]; then
  if [ ! -s "claude-progress.md" ]; then
    echo "[harness] claude-progress.md 为空" >&2
    errors=$((errors + 1))
  fi
else
  echo "[harness] claude-progress.md 不存在" >&2
  errors=$((errors + 1))
fi

if [ "$errors" -gt 0 ]; then
  echo "[harness] 提交被阻止 (${errors} 个问题)。用 --no-verify 跳过检查。" >&2
  exit 1
fi

exit 0
