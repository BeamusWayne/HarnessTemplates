# tests/test_customize.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness customize fails when not initialized" {
  run "$HARNESS_BIN" customize CLAUDE.md
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness customize marks file as customized" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" customize CLAUDE.md
  assert_exit_code 0
  assert_output_contains "customized"
  assert_file_contains ".harness/config.json" "CLAUDE.md"
}

@test "harness customize warns if already customized" {
  "$HARNESS_BIN" init --local
  "$HARNESS_BIN" customize CLAUDE.md
  run "$HARNESS_BIN" customize CLAUDE.md
  assert_exit_code 0
  assert_output_contains "already"
}

@test "harness uncustomize removes file from customized list" {
  "$HARNESS_BIN" init --local
  "$HARNESS_BIN" customize CLAUDE.md
  run "$HARNESS_BIN" uncustomize CLAUDE.md
  assert_exit_code 0
  assert_output_contains "removed"
}
