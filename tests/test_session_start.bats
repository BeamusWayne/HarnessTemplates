# tests/test_session_start.bats
setup() {
  SESSION_START="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.harness/scripts/session-start.sh"
  source tests/test_helper.sh
  setup_test_project
}
teardown() { teardown_test_project; }

# A realistic feature_list.json: status_legend + a feature_template placeholder
# (id feat-NNN) + real features. The hook must look only at the features array.
_write_feature_list() {
  cat > feature_list.json <<'EOF'
{
  "project": "demo",
  "_status": "active",
  "status_legend": {
    "not_started": "功能还没开始做。",
    "blocked": "因为已记录的阻塞问题，当前无法继续推进。"
  },
  "feature_template": {
    "id": "feat-NNN",
    "status": "not_started",
    "blocked_reason": ""
  },
  "features": [
    { "id": "feat-001", "title": "one", "status": "blocked", "blocked_reason": "等待上游 API 凭证" },
    { "id": "feat-002", "title": "two", "status": "not_started" }
  ]
}
EOF
}

@test "session-start does not report the feature_template placeholder id" {
  _write_feature_list
  run bash "$SESSION_START"
  assert_exit_code 0
  ! echo "$output" | grep -q "feat-NNN"
}

@test "session-start surfaces the real active and blocked features" {
  _write_feature_list
  run bash "$SESSION_START"
  assert_exit_code 0
  assert_output_contains "feat-002"            # real not_started feature is "current"
  assert_output_contains "feat-001"            # real blocked feature
  assert_output_contains "等待上游 API 凭证"   # its real blocked reason
}
