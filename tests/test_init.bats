# tests/test_init.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness init creates .harness/config.json" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists ".harness/config.json"
}

@test "harness init creates framework files" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists "CLAUDE.md"
  assert_file_exists "init.sh"
  assert_file_exists "evaluator-rubric.md"
}

@test "harness init creates data files" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists "feature_list.json"
  assert_file_exists "claude-progress.md"
}

@test "harness init creates .harness directory structure" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists ".harness/templates/CLAUDE.md"
  [ -d ".harness/plans/active" ] || { echo "FAIL: plans/active missing"; return 1; }
  [ -d ".harness/plans/completed" ] || { echo "FAIL: plans/completed missing"; return 1; }
  [ -d ".harness/histories" ] || { echo "FAIL: histories missing"; return 1; }
}

@test "harness init creates valid config.json" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_contains ".harness/config.json" "harness_version"
  assert_file_contains ".harness/config.json" "customized_files"
  assert_file_contains ".harness/config.json" "file_categories"
}

@test "harness init refuses to reinitialize" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" init --local
  [ "$status" -ne 0 ]
  assert_output_contains "already initialized"
}

@test "harness init makes init.sh executable" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  [ -x "init.sh" ] || { echo "FAIL: init.sh not executable"; return 1; }
}

@test "harness init deploys .claude/settings.local.json with hooks" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists ".claude/settings.local.json"
  assert_file_contains ".claude/settings.local.json" "PostToolUse"
  assert_file_contains ".claude/settings.local.json" "Stop"
  assert_file_contains ".claude/settings.local.json" "hook-guard.sh"
}

@test "harness init stores project_commands in config.json" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_contains ".harness/config.json" "project_commands"
  assert_file_contains ".harness/config.json" "install"
  assert_file_contains ".harness/config.json" "verify"
  assert_file_contains ".harness/config.json" "start"
}

@test "init.sh reads commands from config.json" {
  "$HARNESS_BIN" init --local
  assert_file_contains "init.sh" "config.json"
}

@test "harness init detects Node.js project" {
  touch package.json
  run "$HARNESS_BIN" init --local --non-interactive
  assert_exit_code 0
  assert_file_contains ".harness/config.json" "npm install"
}

@test "harness init detects Python project" {
  touch requirements.txt
  run "$HARNESS_BIN" init --local --non-interactive
  assert_exit_code 0
  assert_file_contains ".harness/config.json" "pytest"
}

@test "harness init detects Go project" {
  touch go.mod
  run "$HARNESS_BIN" init --local --non-interactive
  assert_exit_code 0
  assert_file_contains ".harness/config.json" "go test"
}

@test "harness init detects Rust project" {
  touch Cargo.toml
  run "$HARNESS_BIN" init --local --non-interactive
  assert_exit_code 0
  assert_file_contains ".harness/config.json" "cargo test"
}

@test "harness init writes valid config.json even with a quote in the directory name" {
  mkdir 'weird"name'
  cd 'weird"name'
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  if command -v python3 >/dev/null 2>&1; then
    run python3 -c "import json; json.load(open('.harness/config.json'))"
    assert_exit_code 0
  elif command -v node >/dev/null 2>&1; then
    run node -e "JSON.parse(require('fs').readFileSync('.harness/config.json','utf8'))"
    assert_exit_code 0
  else
    skip "no JSON parser available"
  fi
}
