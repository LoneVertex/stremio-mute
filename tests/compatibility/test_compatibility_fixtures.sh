#!/usr/bin/env bash
# tests/compatibility/test_compatibility_fixtures.sh — Compatibility Fixture Test Suite
# Tests src/server-wrapper.js against various synthetic and real server.js fixtures to assert fail-closed behavior.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURES_DIR="${REPO_ROOT}/tests/fixtures"
WRAPPER="${REPO_ROOT}/src/server-wrapper.js"

ERRORS=0
TOTAL=0

assert_fixture() {
  local fixture_name="$1"
  local expected_exit="$2"
  local desc="$3"
  
  TOTAL=$((TOTAL+1))
  local fixture_path="${FIXTURES_DIR}/${fixture_name}"
  
  # Run wrapper in isolated child process with target path overridden
  STREMIO_TARGET_SERVER_PATH="$fixture_path" node "$WRAPPER" >/dev/null 2>&1
  local actual_exit=$?
  
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "  [PASS] ${fixture_name} -> exit ${actual_exit} (${desc})"
  else
    echo "  [FAIL] ${fixture_name} -> expected exit ${expected_exit}, got ${actual_exit} (${desc})" >&2
    ERRORS=$((ERRORS+1))
  fi
}

echo "================================================================================"
echo " RUNNING COMPATIBILITY FIXTURE TESTS"
echo "================================================================================"

# 1. Supported server.js fixture (all 3 fingerprints match exactly once) -> exit 0
assert_fixture "server_supported.js" 0 "Supported engine layout succeeds"

# 2. Missing pattern fixture -> exit 1 (FAIL CLOSED)
assert_fixture "server_missing_pattern.js" 1 "Missing pattern fails closed"

# 3. Duplicate pattern fixture -> exit 1 (FAIL CLOSED)
assert_fixture "server_duplicate_pattern.js" 1 "Duplicate pattern fails closed"

# 4. Modified pattern fixture -> exit 1 (FAIL CLOSED)
assert_fixture "server_modified_pattern.js" 1 "Modified syntax fails closed"

echo ""
echo "================================================================================"
if [ "$ERRORS" -eq 0 ]; then
  echo " ALL FIXTURE TESTS PASSED (${TOTAL}/${TOTAL})"
  echo "================================================================================"
  exit 0
else
  echo " FIXTURE TESTS FAILED (${ERRORS}/${TOTAL} failures)"
  echo "================================================================================"
  exit 1
fi
