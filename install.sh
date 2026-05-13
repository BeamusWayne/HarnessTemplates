#!/usr/bin/env bash
# install.sh — Harness CLI 安装器
set -euo pipefail

HARNESS_REPO="BeamusWayne/HarnessTemplates"
HARNESS_BRANCH="main"
INSTALL_DIR="${HOME}/.local/bin"

echo "==> 检测环境"

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  echo "检测到 Windows 原生环境。"
  echo "请使用以下方式之一运行 harness："
  echo "  1. WSL2: wsl bash install.sh"
  echo "  2. Git Bash: 在 Git Bash 终端中运行此脚本"
  exit 1
fi

if ! command -v bash &> /dev/null; then
  echo "错误: 需要 bash 环境。" >&2
  exit 1
fi

if ! command -v curl &> /dev/null; then
  echo "错误: 需要 curl。请安装 curl 后重试。" >&2
  exit 1
fi

echo "  OK: bash + curl 可用"

mkdir -p "$INSTALL_DIR"

echo "==> 下载 harness CLI"
TMPFILE="$(mktemp)"
curl -fsSL "https://raw.githubusercontent.com/${HARNESS_REPO}/${HARNESS_BRANCH}/bin/harness" -o "$TMPFILE"

mv "$TMPFILE" "${INSTALL_DIR}/harness"
chmod +x "${INSTALL_DIR}/harness"

echo "==> 安装完成: ${INSTALL_DIR}/harness"

if ! echo "$PATH" | tr ':' '\n' | grep -qF "$INSTALL_DIR"; then
  echo ""
  echo "注意: ${INSTALL_DIR} 不在 PATH 中。"
  echo "请将以下行添加到 ~/.bashrc 或 ~/.zshrc："
  echo ""
  echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
  echo ""
fi

"${INSTALL_DIR}/harness" version
