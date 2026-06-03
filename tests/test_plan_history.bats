# tests/test_plan_history.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness new-plan fails when not initialized" {
  run "$HARNESS_BIN" new-plan my-plan
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness new-plan requires name argument" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" new-plan
  [ "$status" -ne 0 ]
  assert_output_contains "Usage"
}

@test "harness new-plan creates plan file" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" new-plan auth-refactor
  assert_exit_code 0
  local plan_file
  plan_file=$(ls .harness/plans/active/*auth-refactor* 2>/dev/null | head -1)
  [ -n "$plan_file" ] || { echo "FAIL: plan not created"; return 1; }
}

@test "harness new-plan plan file contains template content" {
  "$HARNESS_BIN" init --local
  "$HARNESS_BIN" new-plan auth-refactor
  local plan_file
  plan_file=$(ls .harness/plans/active/*auth-refactor* 2>/dev/null | head -1)
  assert_file_contains "$plan_file" "执行计划"
  assert_file_contains "$plan_file" "步骤"
}

@test "harness new-history fails when not initialized" {
  run "$HARNESS_BIN" new-history my-history
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness new-history requires name argument" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" new-history
  [ "$status" -ne 0 ]
  assert_output_contains "Usage"
}

@test "harness new-history creates history file" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" new-history fix-login
  assert_exit_code 0
  local hist
  hist=$(find .harness/histories -name "*fix-login*" 2>/dev/null | head -1)
  [ -n "$hist" ] || { echo "FAIL: history not created"; return 1; }
}

@test "harness new-history history file contains template content" {
  "$HARNESS_BIN" init --local
  "$HARNESS_BIN" new-history fix-login
  local hist
  hist=$(find .harness/histories -name "*fix-login*" 2>/dev/null | head -1)
  assert_file_contains "$hist" "变更记录"
  assert_file_contains "$hist" "回归风险"
}

@test "harness new-history creates month directory" {
  "$HARNESS_BIN" init --local
  "$HARNESS_BIN" new-history fix-login
  local month_dir
  month_dir=$(find .harness/histories -mindepth 1 -maxdepth 1 -type d | head -1)
  [ -n "$month_dir" ] || { echo "FAIL: month directory not created"; return 1; }
}
