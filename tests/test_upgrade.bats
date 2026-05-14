# tests/test_upgrade.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness upgrade fails when not initialized" {
  run "$HARNESS_BIN" upgrade --local --auto
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness upgrade skips customized files" {
  "$HARNESS_BIN" init --local
  # Modify and customize CLAUDE.md
  echo "CUSTOM CHANGES" >> CLAUDE.md
  "$HARNESS_BIN" customize CLAUDE.md
  run "$HARNESS_BIN" upgrade --local --auto
  assert_exit_code 0
  assert_output_contains "customized"
  # File should still have our custom changes
  grep -q "CUSTOM CHANGES" CLAUDE.md
}

@test "harness upgrade updates non-customized files" {
  "$HARNESS_BIN" init --local
  # Modify CLAUDE.md but do NOT customize it
  echo "TEMPORARY CHANGE" >> CLAUDE.md
  run "$HARNESS_BIN" upgrade --local --auto
  assert_exit_code 0
  assert_output_contains "updated"
}

@test "harness upgrade never touches data files" {
  "$HARNESS_BIN" init --local
  # Modify data file
  echo "IMPORTANT DATA" >> feature_list.json
  run "$HARNESS_BIN" upgrade --local --auto
  assert_exit_code 0
  # Data file should still have our changes
  grep -q "IMPORTANT DATA" feature_list.json
}
