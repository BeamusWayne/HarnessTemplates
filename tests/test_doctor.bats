# tests/test_doctor.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "harness doctor fails when not initialized" {
  run "$HARNESS_BIN" doctor
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}

@test "harness doctor passes on clean init" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" doctor
  assert_exit_code 0
  assert_output_contains "no issues found"
}

@test "harness doctor reports missing files" {
  "$HARNESS_BIN" init --local
  rm CLAUDE.md
  run "$HARNESS_BIN" doctor
  [ "$status" -ne 0 ]
  assert_output_contains "缺失"
}

@test "harness doctor reports stale version" {
  "$HARNESS_BIN" init --local
  sed -i.bak 's/"harness_version": "2.0.0"/"harness_version": "0.0.1"/' .harness/config.json
  rm -f .harness/config.json.bak
  run "$HARNESS_BIN" doctor
  assert_output_contains "旧"
}

@test "harness doctor checks config.json format" {
  "$HARNESS_BIN" init --local
  run "$HARNESS_BIN" doctor
  assert_exit_code 0
  assert_output_contains "config.json"
}

@test "harness doctor reports missing data file" {
  "$HARNESS_BIN" init --local
  rm feature_list.json
  run "$HARNESS_BIN" doctor
  [ "$status" -ne 0 ]
  assert_output_contains "缺失"
}
