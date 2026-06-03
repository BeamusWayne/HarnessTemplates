# tests/test_upgrade_migration.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}
teardown() { teardown_test_project; }

# Simulate a project initialized before AGENTS.md existed:
# config framework without AGENTS.md, no AGENTS.md file, a full (non-pointer) CLAUDE.md.
_make_pre_agents_project() {
  "$HARNESS_BIN" init --local
  sed -i.bak 's/"CLAUDE.md", "AGENTS.md",/"CLAUDE.md",/' .harness/config.json
  rm -f .harness/config.json.bak
  rm -f AGENTS.md .harness/templates/AGENTS.md
  printf '# CLAUDE.md\n\n(old full rules)\n' > CLAUDE.md
  cp CLAUDE.md .harness/templates/CLAUDE.md
}

@test "upgrade deploys AGENTS.md to a project that predates it" {
  _make_pre_agents_project
  [ ! -f AGENTS.md ]
  run "$HARNESS_BIN" upgrade --local --auto
  assert_exit_code 0
  assert_file_exists "AGENTS.md"
  assert_file_contains ".harness/config.json" "AGENTS.md"
  assert_file_contains "CLAUDE.md" "@AGENTS.md"
}

@test "upgrade migration is idempotent (no duplicate AGENTS.md in config)" {
  _make_pre_agents_project
  "$HARNESS_BIN" upgrade --local --auto
  run "$HARNESS_BIN" upgrade --local --auto
  assert_exit_code 0
  run bash -c "grep -o '\"AGENTS.md\"' .harness/config.json | wc -l | tr -d ' '"
  [ "$output" = "1" ]
}

@test "harness check fails when the canonical AGENTS.md is missing" {
  "$HARNESS_BIN" init --local
  rm -f AGENTS.md
  run "$HARNESS_BIN" check
  [ "$status" -ne 0 ]
  assert_output_contains "MISSING"
}
