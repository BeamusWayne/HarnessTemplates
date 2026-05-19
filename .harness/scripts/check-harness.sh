#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
FIX_MODE=false; [ "${1:-}" = "--fix" ] && FIX_MODE=true
REQUIRED_FILES=(CLAUDE.md init.sh feature_list.json claude-progress.md .harness/config.json)
errors=0; warnings=0
echo "==> Harness 完整性检查"
echo "  [必需文件]"
for f in "${REQUIRED_FILES[@]}"; do
  if [ -f "$f" ]; then echo "    OK: $f"
  else echo "    MISSING: $f"; ((errors++)) || true; fi
done
echo "  [框架文件]"
for f in evaluator-rubric.md autonomous-loop.md self-eval-trigger.md; do
  if [ -f "$f" ]; then echo "    OK: $f"
  else echo "    WARN: $f (可选)"; ((warnings++)) || true; fi
done
echo "  [权限检查]"
if [ -f "init.sh" ]; then
  if [ -x "init.sh" ]; then echo "    OK: init.sh 可执行"
  else echo "    WARN: init.sh 不可执行"; if $FIX_MODE; then chmod +x init.sh && echo "    FIXED"; fi; ((warnings++)) || true; fi
fi
echo "  [格式检查]"
if [ -f "feature_list.json" ]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json; json.load(open('feature_list.json'))" 2>/dev/null; then echo "    OK: feature_list.json 是合法 JSON"
    else echo "    FAIL: feature_list.json 不是合法 JSON"; ((errors++)) || true; fi
  elif command -v node >/dev/null 2>&1; then
    if node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8'))" 2>/dev/null; then echo "    OK: feature_list.json 是合法 JSON"
    else echo "    FAIL: feature_list.json 不是合法 JSON"; ((errors++)) || true; fi
  else
    echo "    SKIP: feature_list.json JSON 验证 (需要 python3 或 node)"
  fi
fi
echo ""; echo "==> 结果: ${errors} 错误, ${warnings} 警告"
[ "$errors" -gt 0 ] && exit 1; exit 0
