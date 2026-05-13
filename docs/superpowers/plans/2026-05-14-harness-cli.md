# Harness CLI 工具实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现一个纯 bash CLI 工具 `harness`，支持 12 个命令，让用户一行命令初始化项目模板并自动管理更新。

**Architecture:** 单文件 bash 脚本 `bin/harness`，函数模块化。安装器 `install.sh` 通过 curl|bash 下载到 ~/.local/bin/。模板文件分三类（框架/数据/脚手架），upgrade 时按类别不同策略处理。

**Tech Stack:** Bash 4+, curl, git, GitHub public API, jq (optional — 用 grep/sed 作 fallback)

**Spec:** `docs/superpowers/specs/2026-05-14-harness-cli-design.md`

---

## File Structure

| File | Responsibility |
|------|---------------|
| `bin/harness` | CLI 主脚本，所有命令入口和逻辑 |
| `install.sh` | 安装器，下载 harness 到 ~/.local/bin/ |
| `tests/test_helper.sh` | 测试工具函数（assert, setup, teardown） |
| `tests/test_version.bats` | version 命令测试 |
| `tests/test_init.bats` | init 命令测试 |
| `tests/test_status.bats` | status 命令测试 |
| `tests/test_check.bats` | check 命令测试 |
| `tests/test_upgrade.bats` | upgrade 命令测试 |
| `tests/test_customize.bats` | customize/uncustomize 命令测试 |
| `tests/test_diff_adopt.bats` | diff/adopt 命令测试 |
| `tests/test_plan_history.bats` | new-plan/new-history 命令测试 |
| `tests/test_report.bats` | report 命令测试 |
| `tests/test_doctor.bats` | doctor 命令测试 |
| `.harness/scripts/check-harness.sh` | 结构完整性检查脚本 |
| `.harness/scripts/ci.sh` | CI 串联脚本 |
| `.harness/templates/plan-template.md` | 执行计划模板 |
| `.harness/templates/history-template.md` | 变更历史模板 |
| `.harness/templates/autonomous-loop.md` | 自治循环协议（来自自治迭代意见书） |
| `.harness/templates/self-eval-trigger.md` | 自我评审触发（来自自治迭代意见书） |

---

## Phase 1: CLI 骨架 + 核心命令（init, status, version, check）

### Task 1: 测试基础设施 + CLI 骨架

**Files:**
- Create: `tests/test_helper.sh`
- Create: `tests/test_version.bats`
- Create: `bin/harness`

- [ ] **Step 1: 安装 bats 测试框架**

```bash
if ! command -v bats &> /dev/null; then
  git clone https://github.com/bats-core/bats-core.git /tmp/bats-core --depth 1
  sudo /tmp/bats-core/install.sh /usr/local
  rm -rf /tmp/bats-core
fi
bats --version
```

- [ ] **Step 2: 创建测试工具函数**

```bash
# tests/test_helper.sh — 每个 bats 测试文件开头 source 此文件

# 创建临时测试项目目录
setup_test_project() {
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
}

# 清理临时目录
teardown_test_project() {
  if [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}

# 断言输出包含指定字符串
assert_output_contains() {
  local needle="$1"
  echo "$output" | grep -qF "$needle" || {
    echo "FAIL: expected output to contain '$needle'"
    echo "Actual output:"
    echo "$output"
    return 1
  }
}

# 断言退出码
assert_exit_code() {
  local expected="$1"
  [ "$status" -eq "$expected" ] || {
    echo "FAIL: expected exit code $expected, got $status"
    echo "Output: $output"
    return 1
  }
}

# 断言文件存在
assert_file_exists() {
  local file="$1"
  [ -f "$file" ] || {
    echo "FAIL: expected file '$file' to exist"
    return 1
  }
}

# 断言文件包含
assert_file_contains() {
  local file="$1"
  local needle="$2"
  grep -qF "$needle" "$file" || {
    echo "FAIL: expected file '$file' to contain '$needle'"
    cat "$file"
    return 1
  }
}
```

- [ ] **Step 3: 写 version 命令的失败测试**

```bash
# tests/test_version.bats
setup() {
  source tests/test_helper.sh
}

@test "harness version prints version string" {
  run bin/harness version
  assert_exit_code 0
  assert_output_contains "harness"
}

@test "harness --version prints version string" {
  run bin/harness --version
  assert_exit_code 0
  assert_output_contains "harness"
}

@test "harness help prints usage" {
  run bin/harness help
  assert_exit_code 0
  assert_output_contains "init"
  assert_output_contains "upgrade"
  assert_output_contains "status"
}
```

- [ ] **Step 4: 运行测试确认失败**

```bash
bats tests/test_version.bats
```

预期：FAIL（bin/harness 不存在）

- [ ] **Step 5: 创建 CLI 骨架**

```bash
#!/usr/bin/env bash
# bin/harness — AI coding agent 脚手架管理工具
set -euo pipefail

HARNESS_VERSION="2.0.0"
HARNESS_REPO="BeamusWayne/HarnessTemplates"
HARNESS_BRANCH="main"

# ── Colors ──────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}==>${NC} $*"; }
log_success() { echo -e "${GREEN}  OK${NC} $*"; }
log_warn()    { echo -e "${YELLOW}  !!${NC} $*"; }
log_error()   { echo -e "${RED}  XX${NC} $*" >&2; }

# ── Config helpers (grep/sed, no jq dependency) ─

config_read_field() {
  local config_path="$1"
  local field="$2"
  grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$config_path" 2>/dev/null | \
    sed 's/.*:.*"\(.*\)"/\1/' || true
}

config_read_array() {
  local config_path="$1"
  local field="$2"
  sed -n "/\"${field}\"/,/\]/p" "$config_path" | \
    grep -o '"[^"]*"' | tr -d '"' | grep -v "^${field}$" || true
}

config_write() {
  local config_path="$1"
  cat > "$config_path"
}

# ── Template URL helpers ────────────────────────

template_raw_url() {
  local path="$1"
  echo "https://raw.githubusercontent.com/${HARNESS_REPO}/${HARNESS_BRANCH}/${path}"
}

fetch_template_to() {
  local path="$1"
  local dest="$2"
  curl -fsSL "$(template_raw_url "$path")" -o "$dest" 2>/dev/null
}

# ── Commands (stubs — filled in later tasks) ────

cmd_version() {
  echo "harness v${HARNESS_VERSION}"
}

cmd_help() {
  cat <<'HELP'
harness — AI coding agent 脚手架管理工具

用法: harness <command> [options]

命令:
  init              在当前项目中初始化 harness
  upgrade           拉取上游模板更新
  status            显示当前状态
  check             运行结构完整性检查
  diff <file>       查看文件的上下游差异
  adopt <file>      接受上游版本
  customize <file>  标记文件为已定制
  uncustomize <file> 取消定制标记
  new-plan <name>   创建执行计划
  new-history <name> 创建变更记录
  report            生成工作总结
  doctor            诊断问题
  version           显示版本
  help              显示帮助

选项:
  --auto            upgrade 时跳过交互
  --dry-run         只显示不执行
  --fix             check 时自动修复
  --local           从本地模板复制（开发/测试用）
HELP
}

# ── Main dispatch ───────────────────────────────

case "${1:-help}" in
  version|--version|-v) cmd_version ;;
  help|--help|-h)       cmd_help ;;
  *)                    echo "harness: unknown command '$1'" >&2; cmd_help >&2; exit 1 ;;
esac
```

```bash
chmod +x bin/harness
```

- [ ] **Step 6: 运行测试确认通过**

```bash
bats tests/test_version.bats
```

预期：3 个测试全部 PASS

- [ ] **Step 7: 提交**

```bash
git add bin/harness tests/test_helper.sh tests/test_version.bats
git commit -m "feat: CLI skeleton with version and help commands"
```

---

### Task 2: install.sh 安装器

**Files:**
- Create: `install.sh`

- [ ] **Step 1: 写安装器**

```bash
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
```

```bash
chmod +x install.sh
```

- [ ] **Step 2: 验证脚本语法**

```bash
bash -n install.sh && echo "语法检查通过"
```

- [ ] **Step 3: 提交**

```bash
git add install.sh
git commit -m "feat: add install.sh for curl|bash installation"
```

---

### Task 3: harness init 命令

**Files:**
- Modify: `bin/harness`（添加 cmd_init 函数和 dispatch 入口）
- Create: `tests/test_init.bats`

- [ ] **Step 1: 写 init 测试**

```bash
# tests/test_init.bats
setup() {
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness init creates .harness/config.json" {
  run bin/harness init --local
  assert_exit_code 0
  assert_file_exists ".harness/config.json"
}

@test "harness init creates framework files" {
  run bin/harness init --local
  assert_exit_code 0
  assert_file_exists "CLAUDE.md"
  assert_file_exists "AGENTS.md"
  assert_file_exists "init.sh"
  assert_file_exists "evaluator-rubric.md"
}

@test "harness init creates data files" {
  run bin/harness init --local
  assert_exit_code 0
  assert_file_exists "feature_list.json"
  assert_file_exists "claude-progress.md"
}

@test "harness init creates .harness directory structure" {
  run bin/harness init --local
  assert_exit_code 0
  assert_file_exists ".harness/templates/CLAUDE.md"
  [ -d ".harness/plans/active" ] || { echo "FAIL: plans/active missing"; return 1; }
  [ -d ".harness/plans/completed" ] || { echo "FAIL: plans/completed missing"; return 1; }
  [ -d ".harness/histories" ] || { echo "FAIL: histories missing"; return 1; }
}

@test "harness init creates valid config.json" {
  run bin/harness init --local
  assert_exit_code 0
  assert_file_contains ".harness/config.json" "harness_version"
  assert_file_contains ".harness/config.json" "customized_files"
  assert_file_contains ".harness/config.json" "file_categories"
}

@test "harness init refuses to reinitialize" {
  bin/harness init --local
  run bin/harness init --local
  [ "$status" -ne 0 ]
  assert_output_contains "already initialized"
}

@test "harness init makes init.sh executable" {
  run bin/harness init --local
  assert_exit_code 0
  [ -x "init.sh" ] || { echo "FAIL: init.sh not executable"; return 1; }
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
bats tests/test_init.bats
```

- [ ] **Step 3: 实现 cmd_init（添加到 bin/harness）**

在 `bin/harness` 的 `# ── Commands` 段落后（cmd_help 之后）添加：

```bash
cmd_init() {
  local use_local=false
  [ "${1:-}" = "--local" ] && use_local=true

  if [ -f ".harness/config.json" ]; then
    log_error "项目已初始化（.harness/config.json 已存在）。"
    echo "  如需重新初始化，先删除 .harness/ 目录。"
    exit 1
  fi

  local project_name
  project_name="$(basename "$PWD")"
  log_info "初始化 harness 项目: $project_name"

  # 确定模板来源
  local template_source
  if $use_local; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    template_source="${script_dir}/../.harness/templates"
    if [ ! -d "$template_source" ]; then
      log_error "本地模板目录不存在: $template_source"
      exit 1
    fi
  else
    log_info "从 GitHub 拉取最新模板..."
    template_source="$(mktemp -d)"
    local all_files="CLAUDE.md AGENTS.md init.sh evaluator-rubric.md feature_list.json claude-progress.md plan-template.md history-template.md"
    for f in $all_files; do
      fetch_template_to ".harness/templates/${f}" "${template_source}/${f}" 2>/dev/null || true
    done
  fi

  # 检测已有文件
  local existing=()
  for f in CLAUDE.md AGENTS.md init.sh evaluator-rubric.md feature_list.json claude-progress.md; do
    [ -f "$f" ] && existing+=("$f")
  done

  if [ ${#existing[@]} -gt 0 ]; then
    log_warn "以下文件已存在，将被覆盖:"
    printf '  - %s\n' "${existing[@]}"
    read -rp "继续? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "已取消。"; exit 0; }
  fi

  # 框架文件 → 项目根目录
  local framework_files="CLAUDE.md AGENTS.md init.sh evaluator-rubric.md"
  for f in $framework_files; do
    if [ -f "${template_source}/${f}" ]; then
      cp "${template_source}/${f}" "./${f}"
      log_success "$f"
    fi
  done

  # 数据文件 → 项目根目录
  for f in feature_list.json claude-progress.md; do
    if [ -f "${template_source}/${f}" ]; then
      cp "${template_source}/${f}" "./${f}"
      log_success "$f"
    fi
  done

  # init.sh 可执行
  [ -f "init.sh" ] && chmod +x init.sh

  # .harness/ 目录结构
  mkdir -p .harness/templates .harness/scripts
  mkdir -p .harness/plans/active .harness/plans/completed
  mkdir -p .harness/histories

  # 框架文件副本 → .harness/templates/
  for f in $framework_files; do
    [ -f "${template_source}/${f}" ] && cp "${template_source}/${f}" ".harness/templates/${f}"
  done

  # 脚手架文件
  for f in plan-template.md history-template.md; do
    [ -f "${template_source}/${f}" ] && cp "${template_source}/${f}" ".harness/templates/${f}"
  done

  # 验证脚本（本地模式从仓库复制）
  if $use_local; then
    local scripts_source="${script_dir}/../.harness/scripts"
    [ -d "$scripts_source" ] && cp "$scripts_source"/* .harness/scripts/ 2>/dev/null || true
  fi

  # 生成 config.json
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  config_write ".harness/config.json" <<CONFIG
{
  "harness_version": "${HARNESS_VERSION}",
  "initialized_at": "${timestamp}",
  "project_name": "${project_name}",
  "customized_files": [],
  "file_categories": {
    "framework": [
      "CLAUDE.md", "AGENTS.md", "init.sh",
      "evaluator-rubric.md",
      "autonomous-loop.md", "self-eval-trigger.md"
    ],
    "data": [
      "feature_list.json", "claude-progress.md"
    ],
    "scaffold": [
      "plan-template.md", "history-template.md"
    ]
  },
  "upstream": {
    "repo": "${HARNESS_REPO}",
    "branch": "${HARNESS_BRANCH}"
  }
}
CONFIG

  log_success ".harness/config.json"
  echo ""
  log_success "初始化完成！"
  echo ""
  echo "下一步:"
  echo "  1. 编辑 feature_list.json 添加你的功能列表"
  echo "  2. 编辑 init.sh 中的 INSTALL_CMD / VERIFY_CMD / START_CMD"
  echo "  3. 让 agent 读取 CLAUDE.md 开始工作"

  if ! $use_local && [ -d "$template_source" ]; then
    rm -rf "$template_source"
  fi
}
```

在 dispatch 中添加：

```bash
init)                  shift; cmd_init "$@" ;;
```

- [ ] **Step 4: 运行测试确认通过**

```bash
bats tests/test_init.bats
```

预期：7 个测试全部 PASS

- [ ] **Step 5: 提交**

```bash
git add bin/harness tests/test_init.bats
git commit -m "feat: add harness init command with local mode"
```

---

### Task 4: harness status 命令

**Files:**
- Modify: `bin/harness`
- Create: `tests/test_status.bats`

- [ ] **Step 1: 写 status 测试**

```bash
# tests/test_status.bats
setup() {
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness status fails when not initialized" {
  run bin/harness status
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness status shows version after init" {
  bin/harness init --local
  run bin/harness status
  assert_exit_code 0
  assert_output_contains "框架版本"
}

@test "harness status shows feature progress" {
  bin/harness init --local
  run bin/harness status
  assert_exit_code 0
  assert_output_contains "功能进度"
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
bats tests/test_status.bats
```

- [ ] **Step 3: 实现 cmd_status（添加到 bin/harness）**

```bash
cmd_status() {
  if [ ! -f ".harness/config.json" ]; then
    log_error "项目未初始化。运行 harness init 开始。"
    exit 1
  fi

  local project_name version
  project_name="$(config_read_field .harness/config.json project_name)"
  version="$(config_read_field .harness/config.json harness_version)"
  project_name="${project_name:-$(basename "$PWD")}"

  echo "项目: ${project_name}"
  echo "框架版本: v${version}"
  echo ""

  if [ -f "feature_list.json" ]; then
    local total passing in_progress blocked not_started
    total=$(grep -c '"id"' feature_list.json 2>/dev/null || echo "0")
    passing=$(grep -c '"status": "passing"' feature_list.json 2>/dev/null || echo "0")
    in_progress=$(grep -c '"status": "in_progress"' feature_list.json 2>/dev/null || echo "0")
    blocked=$(grep -c '"status": "blocked"' feature_list.json 2>/dev/null || echo "0")
    not_started=$(grep -c '"status": "not_started"' feature_list.json 2>/dev/null || echo "0")
    echo "功能进度: ${passing} passing / ${in_progress} in_progress / ${not_started} not_started / ${blocked} blocked / ${total} total"
  else
    echo "功能进度: feature_list.json 不存在"
  fi

  local customized_count
  customized_count=$(config_read_array .harness/config.json customized_files | wc -l | tr -d ' ')
  echo "定制文件: ${customized_count} 个"
}
```

在 dispatch 中添加 `status)` 分支。

- [ ] **Step 4: 运行测试确认通过**

```bash
bats tests/test_status.bats
```

- [ ] **Step 5: 提交**

```bash
git add bin/harness tests/test_status.bats
git commit -m "feat: add harness status command"
```

---

### Task 5: harness check 命令

**Files:**
- Modify: `bin/harness`
- Create: `.harness/scripts/check-harness.sh`
- Create: `tests/test_check.bats`

- [ ] **Step 1: 写 check 测试**

```bash
# tests/test_check.bats
setup() {
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness check fails when not initialized" {
  run bin/harness check
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness check passes after clean init" {
  bin/harness init --local
  run bin/harness check
  assert_exit_code 0
}

@test "harness check reports missing file" {
  bin/harness init --local
  rm CLAUDE.md
  run bin/harness check
  [ "$status" -ne 0 ]
  assert_output_contains "MISSING"
}

@test "harness check reports invalid JSON" {
  bin/harness init --local
  echo "not json" > feature_list.json
  run bin/harness check
  [ "$status" -ne 0 ]
  assert_output_contains "FAIL"
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
bats tests/test_check.bats
```

- [ ] **Step 3: 创建 .harness/scripts/check-harness.sh**

```bash
#!/usr/bin/env bash
# .harness/scripts/check-harness.sh — 验证 harness 文件完整性
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

FIX_MODE=false
[ "${1:-}" = "--fix" ] && FIX_MODE=true

REQUIRED_FILES=(CLAUDE.md AGENTS.md init.sh feature_list.json claude-progress.md .harness/config.json)
FRAMEWORK_FILES=(evaluator-rubric.md)

errors=0
warnings=0

echo "==> Harness 完整性检查"

echo "  [必需文件]"
for f in "${REQUIRED_FILES[@]}"; do
  if [ -f "$f" ]; then
    echo "    OK: $f"
  else
    echo "    MISSING: $f"
    ((errors++)) || true
  fi
done

echo "  [框架文件]"
for f in "${FRAMEWORK_FILES[@]}"; do
  if [ -f "$f" ]; then
    echo "    OK: $f"
  else
    echo "    WARN: $f (可选)"
    ((warnings++)) || true
  fi
done

echo "  [权限检查]"
if [ -f "init.sh" ]; then
  if [ -x "init.sh" ]; then
    echo "    OK: init.sh 可执行"
  else
    echo "    WARN: init.sh 不可执行"
    if $FIX_MODE; then chmod +x init.sh && echo "    FIXED: chmod +x init.sh"; fi
    ((warnings++)) || true
  fi
fi

echo "  [格式检查]"
if [ -f "feature_list.json" ]; then
  if python3 -c "import json; json.load(open('feature_list.json'))" 2>/dev/null || \
     node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8'))" 2>/dev/null; then
    echo "    OK: feature_list.json 是合法 JSON"
  else
    echo "    FAIL: feature_list.json 不是合法 JSON"
    ((errors++)) || true
  fi
fi

crlf_files=$(grep -rl $'\r' --include="*.sh" --include="*.md" --include="*.json" . 2>/dev/null | grep -v '.harness/templates/' || true)
if [ -n "$crlf_files" ]; then
  echo "    WARN: 以下文件含 CRLF:"
  echo "$crlf_files" | while read -r f; do echo "      $f"; done
  if $FIX_MODE; then
    echo "$crlf_files" | while read -r f; do sed -i.bak 's/\r$//' "$f" && rm -f "${f}.bak" && echo "      FIXED: $f"; done
  fi
  ((warnings++)) || true
else
  echo "    OK: 无 CRLF 换行符"
fi

echo ""
echo "==> 结果: ${errors} 错误, ${warnings} 警告"
[ "$errors" -gt 0 ] && exit 1
exit 0
```

```bash
chmod +x .harness/scripts/check-harness.sh
```

- [ ] **Step 4: 实现 cmd_check（添加到 bin/harness）**

```bash
cmd_check() {
  if [ ! -f ".harness/config.json" ]; then
    log_error "项目未初始化。运行 harness init 开始。"
    exit 1
  fi

  local fix_flag=""
  [ "${1:-}" = "--fix" ] && fix_flag="--fix"

  if [ -f ".harness/scripts/check-harness.sh" ]; then
    exec ".harness/scripts/check-harness.sh" $fix_flag
  else
    log_warn "check-harness.sh 不存在，运行基础检查"
    local errors=0
    for f in CLAUDE.md AGENTS.md init.sh feature_list.json; do
      if [ -f "$f" ]; then log_success "$f"
      else log_error "$f 缺失"; ((errors++)) || true; fi
    done
    [ "$errors" -gt 0 ] && exit 1
  fi
}
```

在 dispatch 中添加 `check)` 分支。

- [ ] **Step 5: 运行测试确认通过**

```bash
bats tests/test_check.bats
```

- [ ] **Step 6: 提交**

```bash
git add bin/harness .harness/scripts/check-harness.sh tests/test_check.bats
git commit -m "feat: add harness check command and check-harness.sh"
```

---

### Task 6: Phase 1 集成验证

- [ ] **Step 1: 运行全部 Phase 1 测试**

```bash
bats tests/test_version.bats tests/test_init.bats tests/test_status.bats tests/test_check.bats
```

- [ ] **Step 2: 手动端到端验证**

```bash
cd /tmp && mkdir harness-e2e && cd harness-e2e
/path/to/HarnessTemplates/bin/harness init --local
/path/to/HarnessTemplates/bin/harness status
/path/to/HarnessTemplates/bin/harness check
/path/to/HarnessTemplates/bin/harness version
rm -rf /tmp/harness-e2e
```

- [ ] **Step 3: 提交（如有修复）**

---

## Phase 2: 版本管理命令（upgrade, diff, adopt, customize, uncustomize）

### Task 7: harness customize / uncustomize 命令

**Files:**
- Modify: `bin/harness`
- Create: `tests/test_customize.bats`

- [ ] **Step 1: 写测试**

```bash
# tests/test_customize.bats
setup() {
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness customize adds file to customized_files" {
  bin/harness init --local
  run bin/harness customize CLAUDE.md
  assert_exit_code 0
  assert_file_contains ".harness/config.json" "CLAUDE.md"
}

@test "harness customize rejects non-existent file" {
  bin/harness init --local
  run bin/harness customize nonexistent.md
  [ "$status" -ne 0 ]
}

@test "harness uncustomize removes file from customized_files" {
  bin/harness init --local
  bin/harness customize CLAUDE.md
  run bin/harness uncustomize CLAUDE.md
  assert_exit_code 0
}

@test "harness customize skips already customized file" {
  bin/harness init --local
  bin/harness customize CLAUDE.md
  run bin/harness customize CLAUDE.md
  assert_exit_code 0
  assert_output_contains "already"
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
bats tests/test_customize.bats
```

- [ ] **Step 3: 实现 cmd_customize 和 cmd_uncustomize**

```bash
cmd_customize() {
  local file="${1:-}"
  if [ -z "$file" ]; then log_error "用法: harness customize <file>"; exit 1; fi
  if [ ! -f ".harness/config.json" ]; then log_error "项目未初始化。"; exit 1; fi
  if [ ! -f "$file" ]; then log_error "文件不存在: $file"; exit 1; fi

  local existing
  existing=$(config_read_array .harness/config.json customized_files)
  if echo "$existing" | grep -qF "$file"; then
    log_warn "$file 已在定制列表中。"
    return 0
  fi

  sed -i.bak "/\"customized_files\": \[/a\\    \"$file\"," ".harness/config.json" && rm -f ".harness/config.json.bak"
  log_success "$file 已标记为定制。upgrade 时不会自动更新此文件。"
}

cmd_uncustomize() {
  local file="${1:-}"
  if [ -z "$file" ]; then log_error "用法: harness uncustomize <file>"; exit 1; fi
  if [ ! -f ".harness/config.json" ]; then log_error "项目未初始化。"; exit 1; fi

  sed -i.bak "/\"customized_files\"/,/\]/ s/\"${file}\"[,]?[[:space:]*]//g" ".harness/config.json" && rm -f ".harness/config.json.bak"
  log_success "$file 已取消定制标记。"
}
```

在 dispatch 中添加 `customize)` 和 `uncustomize)` 分支。

- [ ] **Step 4: 运行测试**

```bash
bats tests/test_customize.bats
```

- [ ] **Step 5: 提交**

```bash
git add bin/harness tests/test_customize.bats
git commit -m "feat: add harness customize/uncustomize commands"
```

---

### Task 8: harness diff 命令

**Files:**
- Modify: `bin/harness`
- Create: `tests/test_diff_adopt.bats`

- [ ] **Step 1: 写 diff 测试**

```bash
# tests/test_diff_adopt.bats — diff 和 adopt 的测试
setup() {
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness diff shows identical when files match" {
  bin/harness init --local
  run bin/harness diff CLAUDE.md
  assert_exit_code 0
  assert_output_contains "一致"
}

@test "harness diff shows differences when file modified" {
  bin/harness init --local
  echo "# modified" >> CLAUDE.md
  run bin/harness diff CLAUDE.md
  assert_exit_code 0
  assert_output_contains "modified"
}

@test "harness diff fails for non-existent file" {
  bin/harness init --local
  run bin/harness diff nonexistent.md
  [ "$status" -ne 0 ]
}

@test "harness adopt restores upstream version" {
  bin/harness init --local
  echo "# modified" >> CLAUDE.md
  run bin/harness adopt CLAUDE.md
  assert_exit_code 0
  diff -q CLAUDE.md .harness/templates/CLAUDE.md
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
bats tests/test_diff_adopt.bats
```

- [ ] **Step 3: 实现 cmd_diff 和 cmd_adopt**

```bash
cmd_diff() {
  local file="${1:-}"
  if [ -z "$file" ]; then log_error "用法: harness diff <file>"; exit 1; fi
  if [ ! -f ".harness/config.json" ]; then log_error "项目未初始化。"; exit 1; fi
  if [ ! -f "$file" ]; then log_error "文件不存在: $file"; exit 1; fi

  local template_copy=".harness/templates/${file}"
  if [ ! -f "$template_copy" ]; then log_error "模板原始副本不存在: $template_copy"; exit 1; fi

  if diff -q "$file" "$template_copy" > /dev/null 2>&1; then
    echo "$file: 与上游模板一致（无差异）。"
  else
    echo "-- $file (你的版本 vs 上游模板) --"
    diff -u "$template_copy" "$file" || true
  fi
}

cmd_adopt() {
  local file="${1:-}"
  if [ -z "$file" ]; then log_error "用法: harness adopt <file>"; exit 1; fi
  if [ ! -f ".harness/config.json" ]; then log_error "项目未初始化。"; exit 1; fi

  local template_copy=".harness/templates/${file}"
  if [ ! -f "$template_copy" ]; then log_error "模板原始副本不存在: $template_copy"; exit 1; fi

  cp "$template_copy" "$file"
  log_success "$file 已恢复为上游模板版本。"
  cmd_uncustomize "$file" 2>/dev/null || true
}
```

在 dispatch 中添加 `diff)` 和 `adopt)` 分支。

- [ ] **Step 4: 运行测试**

```bash
bats tests/test_diff_adopt.bats
```

- [ ] **Step 5: 提交**

```bash
git add bin/harness tests/test_diff_adopt.bats
git commit -m "feat: add harness diff and adopt commands"
```

---

### Task 9: harness upgrade 命令

**Files:**
- Modify: `bin/harness`
- Create: `tests/test_upgrade.bats`

- [ ] **Step 1: 写 upgrade 测试**

```bash
# tests/test_upgrade.bats
setup() {
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness upgrade fails when not initialized" {
  run bin/harness upgrade
  [ "$status" -ne 0 ]
}

@test "harness upgrade --local --auto skips customized files" {
  bin/harness init --local
  bin/harness customize CLAUDE.md
  echo "# new upstream" > .harness/templates/CLAUDE.md
  run bin/harness upgrade --local --auto
  assert_exit_code 0
  if grep -q "new upstream" CLAUDE.md; then
    echo "FAIL: customized file was overwritten"; return 1
  fi
}

@test "harness upgrade --local --auto updates non-customized file" {
  bin/harness init --local
  echo "# new rubric" > .harness/templates/evaluator-rubric.md
  run bin/harness upgrade --local --auto
  assert_exit_code 0
  if ! grep -q "new rubric" evaluator-rubric.md; then
    echo "FAIL: non-customized file not updated"; return 1
  fi
}

@test "harness upgrade never touches data files" {
  bin/harness init --local
  echo "user data" >> feature_list.json
  run bin/harness upgrade --local --auto
  assert_exit_code 0
  assert_file_contains "feature_list.json" "user data"
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
bats tests/test_upgrade.bats
```

- [ ] **Step 3: 实现 cmd_upgrade**

```bash
cmd_upgrade() {
  if [ ! -f ".harness/config.json" ]; then
    log_error "项目未初始化。运行 harness init 开始。"
    exit 1
  fi

  local auto_mode=false dry_run=false use_local=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --auto)    auto_mode=true ;;
      --dry-run) dry_run=true ;;
      --local)   use_local=true ;;
      *)         log_error "未知选项: $1"; exit 1 ;;
    esac
    shift
  done

  local current_version
  current_version="$(config_read_field .harness/config.json harness_version)"
  log_info "当前版本: v${current_version}"

  local template_source
  if $use_local; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    template_source="${script_dir}/../.harness/templates"
  else
    log_info "从 GitHub 拉取最新模板..."
    template_source="$(mktemp -d)"
    local framework_files
    framework_files=$(config_read_array .harness/config.json framework | grep -v '^$' || true)
    [ -z "$framework_files" ] && framework_files="CLAUDE.md AGENTS.md init.sh evaluator-rubric.md"
    for f in $framework_files; do
      fetch_template_to ".harness/templates/${f}" "${template_source}/${f}" 2>/dev/null || true
    done
    trap "rm -rf '$template_source'" EXIT
  fi

  local customized_files framework_files
  customized_files=$(config_read_array .harness/config.json customized_files)
  framework_files=$(config_read_array .harness/config.json framework)

  local updated=0 skipped=0 conflicts=0

  for f in $framework_files; do
    local upstream="${template_source}/${f}"
    local template_copy=".harness/templates/${f}"
    local project_file="./${f}"

    [ -f "$upstream" ] || continue

    local is_customized=false
    echo "$customized_files" | grep -qF "$f" && is_customized=true

    if $is_customized; then
      if [ -f "$template_copy" ] && ! diff -q "$template_copy" "$upstream" > /dev/null 2>&1; then
        if $auto_mode; then
          log_warn "$f — 已定制，跳过（--auto 模式）"
          ((skipped++)) || true
        else
          echo ""
          echo "-- $f 有上游更新（已定制） --"
          diff -u "$template_copy" "$upstream" || true
          echo ""
          echo "选择: [a] 采用上游 [k] 保留本地 [s] 跳过"
          read -rp "> " choice
          case "$choice" in
            a|A)
              if ! $dry_run; then
                cp "$upstream" "$project_file"
                cp "$upstream" "$template_copy"
                cmd_uncustomize "$f" 2>/dev/null || true
              fi
              log_success "$f — 已采用上游版本"
              ((updated++)) || true
              ;;
            k|K)
              if ! $dry_run; then cp "$upstream" "$template_copy"; fi
              log_warn "$f — 保留本地版本"
              ((conflicts++)) || true
              ;;
            *)
              log_warn "$f — 跳过"
              ((skipped++)) || true
              ;;
          esac
        fi
      else
        ((skipped++)) || true
      fi
    else
      if [ -f "$template_copy" ] && ! diff -q "$template_copy" "$upstream" > /dev/null 2>&1; then
        if ! $dry_run; then
          cp "$upstream" "$project_file"
          cp "$upstream" "$template_copy"
        fi
        log_success "$f — 已更新"
        ((updated++)) || true
      else
        ((skipped++)) || true
      fi
    fi
  done

  echo ""
  log_info "更新报告: 更新 ${updated}, 跳过 ${skipped}, 保留 ${conflicts}"

  if ! $dry_run; then cmd_check 2>/dev/null || true; fi
}
```

在 dispatch 中添加 `upgrade)` 分支。

- [ ] **Step 4: 运行测试**

```bash
bats tests/test_upgrade.bats
```

- [ ] **Step 5: 提交**

```bash
git add bin/harness tests/test_upgrade.bats
git commit -m "feat: add harness upgrade command with interactive and auto modes"
```

---

### Task 10: Phase 2 集成验证

- [ ] **Step 1: 运行全部测试**

```bash
bats tests/
```

- [ ] **Step 2: 手动端到端测试**

```bash
cd /tmp && rm -rf p2-test && mkdir p2-test && cd p2-test
/path/to/HarnessTemplates/bin/harness init --local
/path/to/HarnessTemplates/bin/harness customize CLAUDE.md
/path/to/HarnessTemplates/bin/harness diff CLAUDE.md
echo "# modified" >> CLAUDE.md
/path/to/HarnessTemplates/bin/harness diff CLAUDE.md
/path/to/HarnessTemplates/bin/harness adopt CLAUDE.md
/path/to/HarnessTemplates/bin/harness upgrade --local --auto
rm -rf /tmp/p2-test
```

- [ ] **Step 3: 提交（如有修复）**

---

## Phase 3: 增值命令（new-plan, new-history, report, doctor）

### Task 11: harness new-plan / new-history 命令

**Files:**
- Modify: `bin/harness`
- Create: `.harness/templates/plan-template.md`
- Create: `.harness/templates/history-template.md`
- Create: `tests/test_plan_history.bats`

- [ ] **Step 1: 创建 plan-template.md**

内容来自 `参考iFurySt修改意见书.md` 3.1.3 节的完整模板。

- [ ] **Step 2: 创建 history-template.md**

内容来自 `参考iFurySt修改意见书.md` 3.1.4 节的完整模板。

- [ ] **Step 3: 写测试**

```bash
# tests/test_plan_history.bats
setup() {
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness new-plan creates plan file" {
  bin/harness init --local
  cp "${BATS_TEST_DIRNAME}/../.harness/templates/plan-template.md" .harness/templates/ 2>/dev/null || true
  run bin/harness new-plan auth-refactor
  assert_exit_code 0
  local plan_file
  plan_file=$(ls .harness/plans/active/*auth-refactor* 2>/dev/null | head -1)
  [ -n "$plan_file" ] || { echo "FAIL: plan not created"; return 1; }
}

@test "harness new-history creates history file" {
  bin/harness init --local
  cp "${BATS_TEST_DIRNAME}/../.harness/templates/history-template.md" .harness/templates/ 2>/dev/null || true
  run bin/harness new-history fix-login
  assert_exit_code 0
  local hist
  hist=$(find .harness/histories -name "*fix-login*" 2>/dev/null | head -1)
  [ -n "$hist" ] || { echo "FAIL: history not created"; return 1; }
}
```

- [ ] **Step 4: 实现 cmd_new_plan 和 cmd_new_history**

```bash
cmd_new_plan() {
  local name="${1:-}"
  if [ -z "$name" ]; then log_error "用法: harness new-plan <name>"; exit 1; fi
  if [ ! -f ".harness/config.json" ]; then log_error "项目未初始化。"; exit 1; fi

  local timestamp filename
  timestamp=$(date +%Y%m%d-%H%M)
  filename=".harness/plans/active/${timestamp}-${name}.md"

  if [ -f ".harness/templates/plan-template.md" ]; then
    cp ".harness/templates/plan-template.md" "$filename"
  else
    cat > "$filename" <<PLAN
# 执行计划：${name}

> 状态：active
> 创建时间：$(date +%Y-%m-%d\ %H:%M)

## 背景

## 目标

## 步骤

| # | 动作 | 状态 | 备注 |
|---|------|------|------|
| 1 | | pending | |

## 验证

- [ ]

## 完成后

- [ ] 更新 feature_list.json
- [ ] 更新 claude-progress.md
PLAN
  fi
  log_success "执行计划已创建: $filename"
}

cmd_new_history() {
  local name="${1:-}"
  if [ -z "$name" ]; then log_error "用法: harness new-history <name>"; exit 1; fi
  if [ ! -f ".harness/config.json" ]; then log_error "项目未初始化。"; exit 1; fi

  local timestamp month_dir filename
  timestamp=$(date +%Y%m%d-%H%M)
  month_dir=".harness/histories/$(date +%Y-%m)"
  mkdir -p "$month_dir"
  filename="${month_dir}/${timestamp}-${name}.md"

  if [ -f ".harness/templates/history-template.md" ]; then
    cp ".harness/templates/history-template.md" "$filename"
  else
    cat > "$filename" <<HIST
# 变更记录：${name}

> 日期：$(date +%Y-%m-%d\ %H:%M)
> 类型：feat

## 改动

## 原因

## 验证

## 影响范围

## 回归风险
HIST
  fi
  log_success "变更记录已创建: $filename"
}
```

在 dispatch 中添加 `new-plan)` 和 `new-history)` 分支。

- [ ] **Step 5: 运行测试**

```bash
bats tests/test_plan_history.bats
```

- [ ] **Step 6: 提交**

```bash
git add bin/harness .harness/templates/plan-template.md .harness/templates/history-template.md tests/test_plan_history.bats
git commit -m "feat: add harness new-plan and new-history commands"
```

---

### Task 12: harness report 命令

**Files:**
- Modify: `bin/harness`
- Create: `tests/test_report.bats`

- [ ] **Step 1: 写测试**

```bash
# tests/test_report.bats
setup() {
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness report fails when not initialized" {
  run bin/harness report
  [ "$status" -ne 0 ]
}

@test "harness report shows feature progress" {
  bin/harness init --local
  run bin/harness report
  assert_exit_code 0
  assert_output_contains "功能进度"
}

@test "harness report shows history count" {
  bin/harness init --local
  run bin/harness report
  assert_exit_code 0
  assert_output_contains "变更历史"
}
```

- [ ] **Step 2: 实现 cmd_report**

```bash
cmd_report() {
  if [ ! -f ".harness/config.json" ]; then log_error "项目未初始化。"; exit 1; fi

  local project_name version
  project_name="$(config_read_field .harness/config.json project_name)"
  version="$(config_read_field .harness/config.json harness_version)"
  project_name="${project_name:-$(basename "$PWD")}"

  echo "== Harness 工作总结 =="
  echo ""
  echo "项目: ${project_name}"
  echo "框架版本: v${version}"
  echo "报告时间: $(date +%Y-%m-%d\ %H:%M)"
  echo ""

  echo "## 功能进度"
  if [ -f "feature_list.json" ]; then
    local total passing in_progress blocked not_started
    total=$(grep -c '"id"' feature_list.json 2>/dev/null || echo "0")
    passing=$(grep -c '"status": "passing"' feature_list.json 2>/dev/null || echo "0")
    in_progress=$(grep -c '"status": "in_progress"' feature_list.json 2>/dev/null || echo "0")
    blocked=$(grep -c '"status": "blocked"' feature_list.json 2>/dev/null || echo "0")
    not_started=$(grep -c '"status": "not_started"' feature_list.json 2>/dev/null || echo "0")
    echo "  passing:      ${passing}"
    echo "  in_progress:  ${in_progress}"
    echo "  blocked:      ${blocked}"
    echo "  not_started:  ${not_started}"
    echo "  total:        ${total}"
  else
    echo "  feature_list.json 不存在"
  fi
  echo ""

  echo "## 变更历史"
  if [ -d ".harness/histories" ]; then
    local history_count
    history_count=$(find .harness/histories -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "  共 ${history_count} 条变更记录"
  else
    echo "  无变更记录"
  fi
  echo ""

  local customized_count
  customized_count=$(config_read_array .harness/config.json customized_files | wc -l | tr -d ' ')
  echo "## 定制文件: ${customized_count} 个"
}
```

在 dispatch 中添加 `report)` 分支。

- [ ] **Step 3: 运行测试**

```bash
bats tests/test_report.bats
```

- [ ] **Step 4: 提交**

```bash
git add bin/harness tests/test_report.bats
git commit -m "feat: add harness report command"
```

---

### Task 13: harness doctor 命令

**Files:**
- Modify: `bin/harness`
- Create: `tests/test_doctor.bats`

- [ ] **Step 1: 写测试**

```bash
# tests/test_doctor.bats
setup() {
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness doctor passes on clean init" {
  bin/harness init --local
  run bin/harness doctor
  assert_exit_code 0
}

@test "harness doctor reports missing files" {
  bin/harness init --local
  rm CLAUDE.md
  run bin/harness doctor
  [ "$status" -ne 0 ]
}

@test "harness doctor reports stale version" {
  bin/harness init --local
  sed -i.bak 's/"harness_version": "2.0.0"/"harness_version": "0.0.1"/' .harness/config.json && rm -f .harness/config.json.bak
  run bin/harness doctor
  assert_output_contains "旧"
}
```

- [ ] **Step 2: 实现 cmd_doctor**

```bash
cmd_doctor() {
  if [ ! -f ".harness/config.json" ]; then log_error "项目未初始化。"; exit 1; fi

  local issues=0
  log_info "诊断 harness 配置..."

  local current_version
  current_version="$(config_read_field .harness/config.json harness_version)"
  if [ "$current_version" != "$HARNESS_VERSION" ]; then
    log_warn "版本过旧: 本地 v${current_version}, 最新 v${HARNESS_VERSION}"
    log_warn "  运行 harness upgrade 更新"
    ((issues++)) || true
  else
    log_success "版本: v${current_version} (最新)"
  fi

  local framework_files
  framework_files=$(config_read_array .harness/config.json framework)
  for f in $framework_files; do
    if [ -f "$f" ]; then log_success "$f 存在"
    else log_warn "$f missing"; ((issues++)) || true; fi
  done

  for f in feature_list.json claude-progress.md; do
    if [ -f "$f" ]; then log_success "$f 存在"
    else log_warn "$f missing"; ((issues++)) || true; fi
  done

  local customized_files
  customized_files=$(config_read_array .harness/config.json customized_files)
  for f in $customized_files; do
    if [ -f "$f" ] && [ -f ".harness/templates/${f}" ]; then
      if ! diff -q "$f" ".harness/templates/${f}" > /dev/null 2>&1; then
        log_warn "$f 有定制修改"
      fi
    fi
  done

  if grep -q '"harness_version"' .harness/config.json && \
     grep -q '"customized_files"' .harness/config.json && \
     grep -q '"file_categories"' .harness/config.json; then
    log_success "config.json 格式正确"
  else
    log_error "config.json 格式异常"
    ((issues++)) || true
  fi

  echo ""
  if [ "$issues" -eq 0 ]; then log_success "诊断通过，无问题。"
  else log_warn "发现 ${issues} 个问题。"; exit 1; fi
}
```

在 dispatch 中添加 `doctor)` 分支。

- [ ] **Step 3: 运行测试**

```bash
bats tests/test_doctor.bats
```

- [ ] **Step 4: 提交**

```bash
git add bin/harness tests/test_doctor.bats
git commit -m "feat: add harness doctor command"
```

---

### Task 14: Phase 3 集成验证

- [ ] **Step 1: 确认 dispatch 包含所有 12 个命令**

```bash
bin/harness help
```

确认输出包含所有命令。

- [ ] **Step 2: 运行全部测试**

```bash
bats tests/
```

- [ ] **Step 3: 提交（如有修复）**

---

## Phase 4: 整合两份修改意见书

### Task 15: 新增模板文件（autonomous-loop.md, self-eval-trigger.md）

**Files:**
- Create: `.harness/templates/autonomous-loop.md`
- Create: `.harness/templates/self-eval-trigger.md`

- [ ] **Step 1: 创建 autonomous-loop.md**

内容来自 `自治迭代修改意见书.md` 第 2.7 节。

- [ ] **Step 2: 创建 self-eval-trigger.md**

内容来自 `自治迭代修改意见书.md` 第 2.8 节。

- [ ] **Step 3: 提交**

```bash
git add .harness/templates/autonomous-loop.md .harness/templates/self-eval-trigger.md
git commit -m "feat: add autonomous-loop and self-eval-trigger templates"
```

---

### Task 16: 更新 CLAUDE.md 和 AGENTS.md 模板

**Files:**
- Modify: `.harness/templates/CLAUDE.md`
- Modify: `.harness/templates/AGENTS.md`

- [ ] **Step 1: 更新 CLAUDE.md — 增加自治迭代循环段落**

在"固定工作循环"之后增加内容来自 `自治迭代修改意见书.md` 2.2 节（外层功能循环、中层验证修复循环、内层构建测试循环、升级条件、提交策略）。

- [ ] **Step 2: 更新 CLAUDE.md — 增加参考文件段落**

在"必需文件"之后增加内容来自 `参考iFurySt修改意见书.md` 3.2.1 节。

- [ ] **Step 3: 更新 AGENTS.md — 增加自治工作模式**

增加内容来自 `自治迭代修改意见书.md` 2.3 节。

- [ ] **Step 4: 提交**

```bash
git add .harness/templates/CLAUDE.md .harness/templates/AGENTS.md
git commit -m "feat: update CLAUDE.md and AGENTS.md templates with autonomous mode"
```

---

### Task 17: 更新 init.sh 模板（子命令模式）

**Files:**
- Modify: `.harness/templates/init.sh`

- [ ] **Step 1: 将 init.sh 改为子命令模式**

内容来自 `参考iFurySt修改意见书.md` 3.2.3 节，但只保留 `(default)`, `health`, `verify` 三个子命令。其他已由 harness CLI 接管。

- [ ] **Step 2: 提交**

```bash
git add .harness/templates/init.sh
git commit -m "feat: update init.sh template with subcommand pattern"
```

---

### Task 18: 更新其余模板文件 + 清理

**Files:**
- Modify: `.harness/templates/feature_list.json`
- Modify: `.harness/templates/claude-progress.md`
- Modify: `.harness/templates/evaluator-rubric.md`
- Modify: `.harness/templates/index.md`
- Create: `.harness/scripts/ci.sh`
- Delete: `.harness/templates/session-handoff.md`
- Delete: `.harness/templates/clean-state-checklist.md`
- Delete: `.harness/templates/quality-document.md`

- [ ] **Step 1: 更新 feature_list.json**

增加 `auto_check` 字段结构和 `autonomous_config` 顶层配置。

- [ ] **Step 2: 更新 claude-progress.md**

精简为索引头 + 自治迭代记录段。

- [ ] **Step 3: 更新 evaluator-rubric.md**

增加自治评审通过线 + 合并 quality-document 的质量快照功能。

- [ ] **Step 4: 创建 ci.sh**

```bash
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
```

- [ ] **Step 5: 更新 index.md**

更新文件列表和说明。

- [ ] **Step 6: 删除已合并的文件**

```bash
rm -f .harness/templates/session-handoff.md
rm -f .harness/templates/clean-state-checklist.md
rm -f .harness/templates/quality-document.md
```

- [ ] **Step 7: 提交**

```bash
git add -A
git commit -m "feat: update all templates, integrate both modification proposals, remove merged files"
```

---

## Phase 5: 文档

### Task 19: 更新 README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 重写 README**

包含：项目介绍、快速开始（curl|bash + harness init）、12 命令速查表、新的模板文件列表、设计原则、安全注意事项。

- [ ] **Step 2: 提交**

```bash
git add README.md
git commit -m "docs: rewrite README for CLI-based workflow"
```

---

### Task 20: 最终验证

- [ ] **Step 1: 运行全部测试**

```bash
bats tests/
```

- [ ] **Step 2: 端到端验证**

```bash
cd /tmp && rm -rf final-test && mkdir final-test && cd final-test
/path/to/HarnessTemplates/bin/harness init --local
/path/to/HarnessTemplates/bin/harness status
/path/to/HarnessTemplates/bin/harness check
/path/to/HarnessTemplates/bin/harness customize CLAUDE.md
/path/to/HarnessTemplates/bin/harness new-plan test-plan
/path/to/HarnessTemplates/bin/harness new-history test-change
/path/to/HarnessTemplates/bin/harness report
/path/to/HarnessTemplates/bin/harness doctor
/path/to/HarnessTemplates/bin/harness upgrade --local --auto
/path/to/HarnessTemplates/bin/harness version
rm -rf /tmp/final-test
```

- [ ] **Step 3: 验证 install.sh 和所有脚本语法**

```bash
bash -n install.sh
bash -n bin/harness
bash -n .harness/scripts/check-harness.sh
```

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "chore: final verification, all phases complete"
```

---

## Self-Review

**Spec Coverage:**

| Spec Section | Task |
|-------------|------|
| 2.1 仓库结构 | Task 1, 15, 18 |
| 2.2 用户项目结构 | Task 3 |
| 2.3 文件三分类 | Task 9 (upgrade) |
| 2.4 去掉的文件 | Task 18 Step 6 |
| 2.5 CLI/init.sh 分工 | Task 3, 17 |
| 3.1 安装 | Task 2 |
| 3.2.1-3.2.12 全部命令 | Tasks 3-14 |
| 4 版本管理 | Task 9 |
| 5.1 自治迭代整合 | Tasks 15-18 |
| 5.2 iFurySt 整合 | Tasks 15-18 |
| 6 错误处理 | Embedded in each command |
| 7 安全 | Task 19 |
| 9 跨平台 | Task 2 |

**Placeholder Scan:** No TBD/TODO found.

**Type Consistency:** All function names use `cmd_*` prefix. JSON fields match between config template and reader functions.
