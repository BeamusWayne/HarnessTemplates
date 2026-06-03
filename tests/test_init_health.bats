# tests/test_init_health.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}
teardown() { teardown_test_project; }

@test "init.sh health SKIPs (does not FAIL) when no verify command is configured" {
  "$HARNESS_BIN" init --local
  run bash init.sh health
  assert_exit_code 0
  assert_output_contains "SKIP"
}
