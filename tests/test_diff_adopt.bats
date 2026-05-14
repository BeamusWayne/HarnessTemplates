# tests/test_diff_adopt.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness diff reports identical files" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" diff CLAUDE.md
  assert_exit_code 0
  assert_output_contains "一致"
}

@test "harness diff shows differences" {
  "$HARNESS_BIN" init --local
  echo "MODIFIED CONTENT" >> CLAUDE.md
  run "$HARNESS_BIN" diff CLAUDE.md
  assert_exit_code 0
  assert_output_contains "differences"
}

@test "harness adopt reverts file to template version" {
  "$HARNESS_BIN" init --local
  echo "MODIFIED CONTENT" >> CLAUDE.md
  run "$HARNESS_BIN" adopt CLAUDE.md
  assert_exit_code 0
  assert_output_contains "adopted"
  # File should now match template
  diff -q CLAUDE.md .harness/templates/CLAUDE.md
}

@test "harness adopt also uncustomizes the file" {
  "$HARNESS_BIN" init --local
  "$HARNESS_BIN" customize CLAUDE.md
  run "$HARNESS_BIN" adopt CLAUDE.md
  assert_exit_code 0
  # File should no longer be in customized_files array
  local customized
  customized="$(sed -n '/"customized_files"/,/\]/p' .harness/config.json | grep -o '"CLAUDE.md"' || true)"
  [ -z "$customized" ]
}
