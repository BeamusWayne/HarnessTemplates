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

@test "harness report (status alias) shows feature progress" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" report
  assert_exit_code 0
  assert_output_contains "Feature progress"
}

@test "harness report (status alias) shows history count" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" report
  assert_exit_code 0
  assert_output_contains "Change histories"
}

@test "harness report (status alias) shows customized file count" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" report
  assert_exit_code 0
  assert_output_contains "Customized files"
}

@test "harness report (status alias) counts history files correctly" {
  "$HARNESS_BIN" init --local
  "$HARNESS_BIN" new-history fix-1
  "$HARNESS_BIN" new-history fix-2
  run "$HARNESS_BIN" report
  assert_exit_code 0
  assert_output_contains "Change histories: 2"
}
