# tests/test_check.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness check fails when not initialized" {
  run "$HARNESS_BIN" check
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness check passes after clean init" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" check
  assert_exit_code 0
  assert_output_contains "OK"
}

@test "harness check reports missing file" {
  "$HARNESS_BIN" init --local
  rm -f CLAUDE.md
  run "$HARNESS_BIN" check
  [ "$status" -ne 0 ]
  assert_output_contains "missing"
}

@test "harness check reports invalid JSON" {
  "$HARNESS_BIN" init --local
  # Copy check-harness.sh into test project for full validation
  local script_src="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.harness/scripts/check-harness.sh"
  cp "$script_src" ".harness/scripts/check-harness.sh"
  chmod +x ".harness/scripts/check-harness.sh"
  echo "NOT VALID JSON {{{" > feature_list.json
  run "$HARNESS_BIN" check
  [ "$status" -ne 0 ]
  assert_output_contains "FAIL"
}
