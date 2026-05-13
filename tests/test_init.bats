# tests/test_init.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness init creates .harness/config.json" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists ".harness/config.json"
}

@test "harness init creates framework files" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists "CLAUDE.md"
  assert_file_exists "AGENTS.md"
  assert_file_exists "init.sh"
  assert_file_exists "evaluator-rubric.md"
}

@test "harness init creates data files" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists "feature_list.json"
  assert_file_exists "claude-progress.md"
}

@test "harness init creates .harness directory structure" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists ".harness/templates/CLAUDE.md"
  [ -d ".harness/plans/active" ] || { echo "FAIL: plans/active missing"; return 1; }
  [ -d ".harness/plans/completed" ] || { echo "FAIL: plans/completed missing"; return 1; }
  [ -d ".harness/histories" ] || { echo "FAIL: histories missing"; return 1; }
}

@test "harness init creates valid config.json" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_contains ".harness/config.json" "harness_version"
  assert_file_contains ".harness/config.json" "customized_files"
  assert_file_contains ".harness/config.json" "file_categories"
}

@test "harness init refuses to reinitialize" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" init --local
  [ "$status" -ne 0 ]
  assert_output_contains "already initialized"
}

@test "harness init makes init.sh executable" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  [ -x "init.sh" ] || { echo "FAIL: init.sh not executable"; return 1; }
}
