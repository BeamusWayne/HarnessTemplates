# tests/test_query.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}
teardown() { teardown_test_project; }

@test "query --today finds an event written today" {
  "$HARNESS_BIN" init --local
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "{\"ts\":\"$TS\",\"event\":\"verification_result\",\"feature\":\"f1\",\"result\":\"pass\"}" >> .harness/world/events.jsonl
  run "$HARNESS_BIN" query --today
  assert_exit_code 0
  assert_output_contains "verification_result"
}

@test "query --since <date> finds an event from that date" {
  "$HARNESS_BIN" init --local
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "{\"ts\":\"$TS\",\"event\":\"feature_status_change\",\"feature\":\"f2\"}" >> .harness/world/events.jsonl
  run "$HARNESS_BIN" query --since "$(date -u +%Y-%m-%d)"
  assert_exit_code 0
  assert_output_contains "feature_status_change"
}

@test "query <pattern> filters events" {
  "$HARNESS_BIN" init --local
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "{\"ts\":\"$TS\",\"event\":\"escalation\",\"feature\":\"f3\"}" >> .harness/world/events.jsonl
  run "$HARNESS_BIN" query escalation
  assert_exit_code 0
  assert_output_contains "escalation"
}
