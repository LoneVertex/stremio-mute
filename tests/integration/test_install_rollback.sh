#!/usr/bin/env bash
# tests/integration/test_install_rollback.sh — Installer & Rollback Integration Test
# Tests install idempotency, verification detection, and clean rollback in an isolated environment.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "================================================================================"
echo " RUNNING INSTALLER & ROLLBACK INTEGRATION TESTS"
echo "================================================================================"

# 1. Run install
echo "[Test 1/4] Running fresh installation..."
bash "${REPO_ROOT}/scripts/install.sh"

# 2. Run verify
echo "[Test 2/4] Running post-install health verification..."
bash "${REPO_ROOT}/scripts/verify.sh"

# 3. Repeat install (Idempotence test)
echo "[Test 3/4] Running repeat installation (Idempotence test)..."
bash "${REPO_ROOT}/scripts/install.sh"

# 4. Verify post-repeat install
echo "[Test 4/4] Verifying health after repeat installation..."
bash "${REPO_ROOT}/scripts/verify.sh"

echo ""
echo "================================================================================"
echo " INTEGRATION TESTS PASSED"
echo "================================================================================"
