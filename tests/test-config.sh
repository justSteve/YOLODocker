#!/bin/bash
set -uo pipefail

# Test suite for config validation

# Define error function (needed by config.sh)
error() {
  echo "ERROR: $*" >&2
  return 1
}

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/bin/lib/config.sh"

# Counter for test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Create temp directory for test files
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Test 1: Valid minimal config
cat > "$TEST_DIR/valid-minimal.json" <<'EOF'
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

config=$(load_config "$TEST_DIR/valid-minimal.json")
if validate_config "$config" &>/dev/null; then
  ((TESTS_PASSED++))
  echo "✓ Valid minimal config passes validation"
else
  ((TESTS_FAILED++))
  echo "✗ Valid minimal config passes validation"
fi
((TESTS_RUN++))

# Test 2: Valid multi-service config
cat > "$TEST_DIR/valid-multi.json" <<'EOF'
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
  },
  "systemPackages": ["ffmpeg"],
  "externalAPIs": ["http://localhost:3000"]
}
EOF

config=$(load_config "$TEST_DIR/valid-multi.json")
if validate_config "$config" &>/dev/null; then
  ((TESTS_PASSED++))
  echo "✓ Valid multi-service config passes validation"
else
  ((TESTS_FAILED++))
  echo "✗ Valid multi-service config passes validation"
fi
((TESTS_RUN++))

# Test 3: Invalid JSON
cat > "$TEST_DIR/invalid.json" <<'EOF'
{ broken json
EOF

if load_config "$TEST_DIR/invalid.json" &>/dev/null; then
  ((TESTS_FAILED++))
  echo "✗ Invalid JSON rejected"
else
  ((TESTS_PASSED++))
  echo "✓ Invalid JSON rejected"
fi
((TESTS_RUN++))

# Test 4: Missing services
cat > "$TEST_DIR/no-services.json" <<'EOF'
{
  "systemPackages": []
}
EOF

config=$(load_config "$TEST_DIR/no-services.json")
if validate_config "$config" &>/dev/null; then
  ((TESTS_FAILED++))
  echo "✗ Config without services rejected"
else
  ((TESTS_PASSED++))
  echo "✓ Config without services rejected"
fi
((TESTS_RUN++))

# Test 5: Empty services
cat > "$TEST_DIR/empty-services.json" <<'EOF'
{
  "services": {}
}
EOF

config=$(load_config "$TEST_DIR/empty-services.json")
if validate_config "$config" &>/dev/null; then
  ((TESTS_FAILED++))
  echo "✗ Config with zero services rejected"
else
  ((TESTS_PASSED++))
  echo "✓ Config with zero services rejected"
fi
((TESTS_RUN++))

# Test 6: Missing required service field
cat > "$TEST_DIR/missing-field.json" <<'EOF'
{
  "services": {
    "web": {
      "runtime": "node",
      "port": 3000
    }
  }
}
EOF

config=$(load_config "$TEST_DIR/missing-field.json")
if validate_config "$config" &>/dev/null; then
  ((TESTS_FAILED++))
  echo "✗ Service missing startCommand rejected"
else
  ((TESTS_PASSED++))
  echo "✓ Service missing startCommand rejected"
fi
((TESTS_RUN++))

# Test 7: Invalid runtime
cat > "$TEST_DIR/invalid-runtime.json" <<'EOF'
{
  "services": {
    "web": {
      "runtime": "ruby",
      "port": 3000,
      "startCommand": "ruby app.rb"
    }
  }
}
EOF

config=$(load_config "$TEST_DIR/invalid-runtime.json")
if validate_config "$config" &>/dev/null; then
  ((TESTS_FAILED++))
  echo "✗ Invalid runtime rejected"
else
  ((TESTS_PASSED++))
  echo "✓ Invalid runtime rejected"
fi
((TESTS_RUN++))

# Test 8: Invalid port (non-numeric)
cat > "$TEST_DIR/invalid-port.json" <<'EOF'
{
  "services": {
    "web": {
      "runtime": "node",
      "port": "abc",
      "startCommand": "npm start"
    }
  }
}
EOF

config=$(load_config "$TEST_DIR/invalid-port.json")
if validate_config "$config" &>/dev/null; then
  ((TESTS_FAILED++))
  echo "✗ Non-numeric port rejected"
else
  ((TESTS_PASSED++))
  echo "✓ Non-numeric port rejected"
fi
((TESTS_RUN++))

# Test 9: Get service names
cat > "$TEST_DIR/multi-service.json" <<'EOF'
{
  "services": {
    "web": {"runtime": "node", "port": 3000, "startCommand": "npm start"},
    "api": {"runtime": "python", "port": 3001, "startCommand": "python app.py"}
  }
}
EOF

config=$(load_config "$TEST_DIR/multi-service.json")
services=$(get_service_names "$config")
if [[ "$services" == *"web"* ]] && [[ "$services" == *"api"* ]]; then
  ((TESTS_PASSED++))
  echo "✓ Get service names returns both services"
else
  ((TESTS_FAILED++))
  echo "✗ Get service names returns both services"
fi
((TESTS_RUN++))

# Print results
echo ""
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -gt 0 ]]; then
  exit 1
fi
