# tests/test_status.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness status fails when not initialized" {
  run "$HARNESS_BIN" status
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness status shows version" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" status
  assert_exit_code 0
  assert_output_contains "Harness version"
}

@test "harness status shows feature progress" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" status
  assert_exit_code 0
  assert_output_contains "passing"
  assert_output_contains "in_progress"
  assert_output_contains "blocked"
  assert_output_contains "not_started"
}
