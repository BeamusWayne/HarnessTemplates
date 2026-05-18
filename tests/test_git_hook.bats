# tests/test_git_hook.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  GIT_HOOK="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.harness/scripts/git-pre-commit.sh"
  source tests/test_helper.sh
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "git hook blocks commit with invalid feature_list.json" {
  git init
  echo "NOT JSON {{{" > feature_list.json
  echo "# progress" > claude-progress.md
  run bash "$GIT_HOOK"
  [ "$status" -ne 0 ]
  assert_output_contains "feature_list.json"
}

@test "git hook blocks commit with empty claude-progress.md" {
  git init
  echo '{"features":[]}' > feature_list.json
  touch claude-progress.md
  run bash "$GIT_HOOK"
  [ "$status" -ne 0 ]
  assert_output_contains "claude-progress.md"
}

@test "git hook passes with valid files" {
  git init
  echo '{"features":[]}' > feature_list.json
  echo "# progress" > claude-progress.md
  run bash "$GIT_HOOK"
  assert_exit_code 0
}

@test "harness init installs git pre-commit hook" {
  git init
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  assert_file_exists ".git/hooks/pre-commit"
  assert_file_contains ".git/hooks/pre-commit" "managed by harness"
}

@test "harness init auto-creates git repo and installs hook" {
  run "$HARNESS_BIN" init --local
  assert_exit_code 0
  [ -d ".git" ]
  [ -f ".git/hooks/pre-commit" ]
}
