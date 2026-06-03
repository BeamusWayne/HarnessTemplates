# tests/test_hook_guard_plan.bats
setup() {
  HOOK_GUARD="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.harness/scripts/hook-guard.sh"
  source tests/test_helper.sh
  setup_test_project
}
teardown() { teardown_test_project; }

@test "post-edit does not crash when plans/active holds an unfilled template" {
  mkdir -p .harness/plans/active
  echo "# 执行计划：<任务标题>" > .harness/plans/active/p1.md
  cat > feature_list.json <<'EOF'
{
  "features": [
    {"id": "f1", "status": "in_progress", "plan_file": ""}
  ]
}
EOF
  run bash "$HOOK_GUARD" post-edit
  assert_exit_code 0
  assert_output_contains "空模板"
}
