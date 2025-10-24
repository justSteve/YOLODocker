#!/bin/bash
set -euo pipefail

# Test suite for supervisor config generation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Helper functions needed by libraries
error() {
  echo "ERROR: $*" >&2
  return 1
}

info() {
  echo "INFO: $*"
}

source "$SCRIPT_DIR/bin/lib/config.sh"
source "$SCRIPT_DIR/bin/lib/supervisor-config.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_match() {
  local test_name="$1"
  local file="$2"
  local pattern="$3"

  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "$pattern" "$file"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ $test_name"
  fi
}

assert_not_match() {
  local test_name="$1"
  local file="$2"
  local pattern="$3"

  TESTS_RUN=$((TESTS_RUN + 1))
  if ! grep -q "$pattern" "$file"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ $test_name"
  fi
}

# Create temp directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Test 1: Single service config
cat > "$TEST_DIR/single-service.json" <<'EOF'
{
  "services": {
    "web": {
      "runtime": "node",
      "port": 3000,
      "startCommand": "npm start"
    }
  }
}
EOF

config=$(load_config "$TEST_DIR/single-service.json")
generate_supervisor_config "$config" "$TEST_DIR/supervisord.conf"

assert_match "Config includes supervisord section" "$TEST_DIR/supervisord.conf" "\[supervisord\]"
assert_match "Config includes program for web service" "$TEST_DIR/supervisord.conf" "\[program:web\]"
assert_match "Config includes start command" "$TEST_DIR/supervisord.conf" "command=npm start"
assert_match "Config sets autostart=true" "$TEST_DIR/supervisord.conf" "autostart=true"

# Test 2: Multi-service config
cat > "$TEST_DIR/multi-service.json" <<'EOF'
{
  "services": {
    "web": {
      "runtime": "node",
      "port": 3000,
      "startCommand": "npm start"
    },
    "trading": {
      "runtime": "python",
      "port": 3001,
      "startCommand": "python -m trading.service"
    }
  }
}
EOF

config=$(load_config "$TEST_DIR/multi-service.json")
generate_supervisor_config "$config" "$TEST_DIR/supervisord-multi.conf"

assert_match "Config includes both services" "$TEST_DIR/supervisord-multi.conf" "\[program:web\]"
assert_match "Config includes trading service" "$TEST_DIR/supervisord-multi.conf" "\[program:trading\]"
assert_match "Config includes both start commands" "$TEST_DIR/supervisord-multi.conf" "command=npm start"
assert_match "Config includes Python start command" "$TEST_DIR/supervisord-multi.conf" "command=python -m trading.service"

# Print results
echo ""
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -gt 0 ]]; then
  exit 1
fi
