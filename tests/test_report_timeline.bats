# tests/test_report_timeline.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}
teardown() { teardown_test_project; }

@test "report shows status content AND an event timeline" {
  "$HARNESS_BIN" init --local
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "{\"ts\":\"$TS\",\"event\":\"verification_result\",\"feature\":\"f1\",\"result\":\"pass\"}" >> .harness/world/events.jsonl
  run "$HARNESS_BIN" report
  assert_exit_code 0
  assert_output_contains "Feature progress"
  assert_output_contains "事件时间线"
}

@test "report fails when not initialized" {
  run "$HARNESS_BIN" report
  [ "$status" -ne 0 ]
  assert_output_contains "not initialized"
}
