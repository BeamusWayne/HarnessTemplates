# tests/test_report.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness report fails when not initialized" {
  run "$HARNESS_BIN" report
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness report shows feature progress" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" report
  assert_exit_code 0
  assert_output_contains "功能进度"
}

@test "harness report shows history count" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" report
  assert_exit_code 0
  assert_output_contains "变更历史"
}

@test "harness report shows customized file count" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" report
  assert_exit_code 0
  assert_output_contains "定制文件"
}

@test "harness report counts history files correctly" {
  "$HARNESS_BIN" init --local
  "$HARNESS_BIN" new-history fix-1
  "$HARNESS_BIN" new-history fix-2
  run "$HARNESS_BIN" report
  assert_exit_code 0
  assert_output_contains "2 file(s)"
}
