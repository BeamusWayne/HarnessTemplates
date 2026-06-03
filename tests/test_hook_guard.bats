# tests/test_hook_guard.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  HOOK_GUARD="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.harness/scripts/hook-guard.sh"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "hook-guard post-edit warns when no in_progress feature" {
  cat > feature_list.json <<'EOF'
{
  "features": [
    {"id": "f1", "status": "not_started"}
  ]
}
EOF
  run bash "$HOOK_GUARD" post-edit
  assert_exit_code 0
  assert_output_contains "没有进行中的功能"
}

@test "hook-guard post-edit is silent when feature in_progress" {
  cat > feature_list.json <<'EOF'
{
  "features": [
    {"id": "f1", "status": "in_progress"}
  ]
}
EOF
  run bash "$HOOK_GUARD" post-edit
  assert_exit_code 0
  ! echo "$output" | grep -q "没有进行中的功能"
}

@test "hook-guard post-edit is silent when feature_list.json missing" {
  run bash "$HOOK_GUARD" post-edit
  assert_exit_code 0
}

@test "hook-guard pre-stop warns when progress not updated" {
  mkdir -p .harness
  touch -t 202501010000 .harness/.session-start
  echo "# old progress" > claude-progress.md
  touch -t 202501010000 claude-progress.md
  run bash "$HOOK_GUARD" pre-stop
  assert_exit_code 0
  assert_output_contains "未更新"
}

@test "hook-guard pre-stop is silent when progress was updated" {
  mkdir -p .harness
  touch .harness/.session-start
  sleep 1
  echo "# fresh progress" > claude-progress.md
  run bash "$HOOK_GUARD" pre-stop
  assert_exit_code 0
  ! echo "$output" | grep -q "未更新"
}
