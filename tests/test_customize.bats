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
  # the rewrite must not drop other config keys (regression: it deleted these)
  assert_file_contains ".harness/config.json" "project_commands"
  assert_file_contains ".harness/config.json" "framework"
}

@test "harness customize keeps config.json valid JSON" {
  "$HARNESS_BIN" init --local
  "$HARNESS_BIN" customize CLAUDE.md
  if command -v python3 >/dev/null 2>&1; then
    run python3 -c "import json; json.load(open('.harness/config.json'))"
    assert_exit_code 0
  elif command -v node >/dev/null 2>&1; then
    run node -e "JSON.parse(require('fs').readFileSync('.harness/config.json','utf8'))"
    assert_exit_code 0
  else
    skip "no JSON parser available"
  fi
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
  # uncustomize shares the rewrite path — config must stay intact
  assert_file_contains ".harness/config.json" "framework"
}
