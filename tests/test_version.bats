# tests/test_version.bats
setup() {
  source tests/test_helper.sh
}

@test "harness version prints version string" {
  run bin/harness version
  assert_exit_code 0
  assert_output_contains "harness"
}

@test "harness --version prints version string" {
  run bin/harness --version
  assert_exit_code 0
  assert_output_contains "harness"
}

@test "harness help prints usage" {
  run bin/harness help
  assert_exit_code 0
  assert_output_contains "init"
  assert_output_contains "upgrade"
  assert_output_contains "status"
}
