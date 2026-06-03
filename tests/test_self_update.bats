# tests/test_self_update.bats
setup() {
  HARNESS_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/harness"
  source tests/test_helper.sh
  setup_test_project
}
teardown() { teardown_test_project; }

@test "self-update replaces the CLI binary from the resolved source" {
  printf '#!/usr/bin/env bash\nHARNESS_VERSION="9.9.9"\necho hi\n' > fixture-harness
  cp "$HARNESS_BIN" target-harness
  export HARNESS_SELF_TARGET="$PWD/target-harness"
  export HARNESS_SELF_SOURCE="file://$PWD/fixture-harness"
  run "$HARNESS_BIN" self-update
  unset HARNESS_SELF_TARGET HARNESS_SELF_SOURCE
  assert_exit_code 0
  assert_output_contains "9.9.9"
  assert_file_contains "target-harness" 'HARNESS_VERSION="9.9.9"'
  [ -x target-harness ]
}

@test "self-update aborts and leaves the CLI untouched if the download is not a harness CLI" {
  printf 'this is not the harness cli\n' > junk
  cp "$HARNESS_BIN" target-harness
  export HARNESS_SELF_TARGET="$PWD/target-harness"
  export HARNESS_SELF_SOURCE="file://$PWD/junk"
  run "$HARNESS_BIN" self-update
  unset HARNESS_SELF_TARGET HARNESS_SELF_SOURCE
  [ "$status" -ne 0 ]
  assert_output_contains "已中止"
  # the existing CLI must be intact (not overwritten with junk)
  assert_file_contains "target-harness" "HARNESS_VERSION"
  run grep -c "not the harness cli" target-harness
  [ "$output" = "0" ]
}

@test "self-update follows a symlink and updates the real file, not the link" {
  printf '#!/usr/bin/env bash\nHARNESS_VERSION="9.9.9"\n' > fixture-harness
  cp "$HARNESS_BIN" real-cli
  ln -s "$PWD/real-cli" link-cli
  export HARNESS_SELF_TARGET="$PWD/link-cli"
  export HARNESS_SELF_SOURCE="file://$PWD/fixture-harness"
  run "$HARNESS_BIN" self-update
  unset HARNESS_SELF_TARGET HARNESS_SELF_SOURCE
  assert_exit_code 0
  [ -L link-cli ]                                            # the symlink is preserved
  assert_file_contains "real-cli" 'HARNESS_VERSION="9.9.9"'  # the real file was updated
}
