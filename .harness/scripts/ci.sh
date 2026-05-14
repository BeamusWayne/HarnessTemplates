#!/usr/bin/env bash
set -euo pipefail
echo "========== Harness CI =========="
echo "==> 1/3 结构检查"
./.harness/scripts/check-harness.sh
echo "==> 2/3 环境健康检查"
./init.sh health
echo "==> 3/3 功能验证"
./init.sh verify
echo "========== 全部通过 =========="
