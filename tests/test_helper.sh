# tests/test_helper.sh
setup_test_project() {
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
}

teardown_test_project() {
  if [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}

assert_output_contains() {
  local needle="$1"
  echo "$output" | grep -qF "$needle" || {
    echo "FAIL: expected output to contain '$needle'"
    echo "Actual output:"
    echo "$output"
    return 1
  }
}

assert_exit_code() {
  local expected="$1"
  [ "$status" -eq "$expected" ] || {
    echo "FAIL: expected exit code $expected, got $status"
    echo "Output: $output"
    return 1
  }
}

assert_file_exists() {
  local file="$1"
  [ -f "$file" ] || {
    echo "FAIL: expected file '$file' to exist"
    return 1
  }
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  grep -qF "$needle" "$file" || {
    echo "FAIL: expected file '$file' to contain '$needle'"
    cat "$file"
    return 1
  }
}
