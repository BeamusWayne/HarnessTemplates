# tests/test_changelog.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness changelog fails when not initialized" {
  run "$HARNESS_BIN" changelog
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness changelog runs when initialized" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" changelog
  assert_exit_code 0
}
