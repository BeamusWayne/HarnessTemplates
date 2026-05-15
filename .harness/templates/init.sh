#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

read_cmd() {
  local field="$1"
  local default="$2"
  local value=""
  if [ -f ".harness/config.json" ]; then
    value="$(grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" .harness/config.json 2>/dev/null | head -1 | sed 's/.*:.*"\(.*\)"/\1/' || true)"
  fi
  echo "${value:-$default}"
}

INSTALL_CMD="$(read_cmd install '')"
VERIFY_CMD="$(read_cmd verify '')"
START_CMD="$(read_cmd start '')"

case "${1:-default}" in
  default)
    echo "==> 当前目录: $PWD"
    if [ -n "$INSTALL_CMD" ]; then
      echo "==> 同步依赖"
      eval "$INSTALL_CMD"
    else
      echo "==> 跳过依赖安装 (未检测到项目类型，可在 .harness/config.json 中配置)"
    fi
    if [ -n "$VERIFY_CMD" ]; then
      echo "==> 运行基础验证"
      eval "$VERIFY_CMD"
    else
      echo "==> 跳过验证 (未检测到项目类型，可在 .harness/config.json 中配置)"
    fi
    if [ -n "$START_CMD" ]; then
      echo "==> 启动命令"
      echo "    $START_CMD"
      if [ "${RUN_START_COMMAND:-0}" = "1" ]; then
        echo "==> 启动应用"
        eval "exec $START_CMD"
      fi
      echo "如果希望 init.sh 直接启动应用，请设置 RUN_START_COMMAND=1。"
    fi
    ;;

  health)
    echo "==> [健康检查] 目录: $PWD"
    PORT="${APP_PORT:-3000}"
    if command -v lsof &> /dev/null && lsof -i ":$PORT" > /dev/null 2>&1; then
      echo "WARN: 端口 $PORT 已被占用"
    else
      echo "  OK: 端口 $PORT 可用"
    fi
    if [ -n "$VERIFY_CMD" ] && eval "$VERIFY_CMD" > /dev/null 2>&1; then
      echo "  OK: 基础验证通过"
    else
      echo "FAIL: 基础验证失败"; exit 1
    fi
    echo "==> 健康检查通过"
    ;;

  verify)
    if [ -n "$VERIFY_CMD" ]; then
      echo "==> 运行功能验证"
      eval "$VERIFY_CMD"
    else
      echo "==> 跳过验证 (未配置 verify 命令)"
    fi
    ;;

  *)
    echo "用法: ./init.sh [command]"
    echo ""
    echo "命令:"
    echo "  (default)  安装依赖 + 跑验证"
    echo "  health     环境健康检查"
    echo "  verify     只跑功能验证"
    ;;
esac
