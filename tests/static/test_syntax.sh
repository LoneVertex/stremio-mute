#!/usr/bin/env bash
# tests/static/test_syntax.sh — Static Syntax and Lint Runner
# Tests shell and JavaScript syntax across the repository.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ERRORS=0
TOTAL=0

assert_sh() {
  local file="$1"
  TOTAL=$((TOTAL+1))
  if bash -n "$file" 2>/dev/null; then
    echo "  [PASS] Shell syntax: ${file#"${REPO_ROOT}/"}"
  else
    echo "  [FAIL] Shell syntax error: ${file#"${REPO_ROOT}/"}" >&2
    ERRORS=$((ERRORS+1))
  fi
}

assert_js() {
  local file="$1"
  TOTAL=$((TOTAL+1))
  if node -c "$file" 2>/dev/null; then
    echo "  [PASS] JS syntax: ${file#"${REPO_ROOT}/"}"
  else
    echo "  [FAIL] JS syntax error: ${file#"${REPO_ROOT}/"}" >&2
    ERRORS=$((ERRORS+1))
  fi
}

echo "================================================================================"
echo " RUNNING STATIC SYNTAX TESTS"
echo "================================================================================"

while IFS= read -r f; do
  assert_sh "$f"
done < <(find "${REPO_ROOT}" -type f -name "*.sh" -not -path '*/.git/*')

while IFS= read -r f; do
  assert_js "$f"
done < <(find "${REPO_ROOT}" -type f -name "*.js" -not -path '*/.git/*')

echo ""
echo "================================================================================"
if [ "$ERRORS" -eq 0 ]; then
  echo " ALL SYNTAX TESTS PASSED (${TOTAL}/${TOTAL})"
  echo "================================================================================"
  exit 0
else
  echo " SYNTAX TESTS FAILED (${ERRORS}/${TOTAL} failures)"
  echo "================================================================================"
  exit 1
fi
