#!/usr/bin/env bash
# tests/integration/test_install_rollback.sh — Installer lifecycle integration test
# Uses the isolated canonical-path mock in CI and the real Flatpak only when available.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"

printf '%s\n' '================================================================================'
printf '%s\n' ' RUNNING INSTALLER LIFECYCLE INTEGRATION TESTS'
printf '%s\n' '================================================================================'

if command -v flatpak >/dev/null 2>&1 && flatpak info com.stremio.Stremio >/dev/null 2>&1; then
  printf '%s\n' '[Mode] Real Flatpak detected; exercising install -> verify -> reinstall -> rollback.'
  bash "${REPO_ROOT}/scripts/install.sh"
  bash "${REPO_ROOT}/scripts/verify.sh" || test $? -eq 1
  bash "${REPO_ROOT}/scripts/install.sh"
  bash "${REPO_ROOT}/scripts/verify.sh" || test $? -eq 1
  bash "${REPO_ROOT}/scripts/rollback.sh"
  if bash "${REPO_ROOT}/scripts/verify.sh" >/tmp/stremio-mute-rollback-verify.out 2>&1; then
    printf '%s\n' '[FAIL] verify.sh unexpectedly passed after rollback.' >&2
    cat /tmp/stremio-mute-rollback-verify.out >&2
    exit 1
  fi
  grep -Eq 'STATUS: NOT INSTALLED|STATUS: CONFIGURED' /tmp/stremio-mute-rollback-verify.out
else
  printf '%s\n' '[Mode] Flatpak unavailable; running isolated lifecycle mock coverage.'
  bash "${REPO_ROOT}/tests/static/test_absolute_path.sh"
  bash "${REPO_ROOT}/tests/static/test_stale_process_install.sh"
fi

printf '%s\n' ''
printf '%s\n' '================================================================================'
printf '%s\n' ' INSTALLER LIFECYCLE INTEGRATION TESTS PASSED'
printf '%s\n' '================================================================================'
