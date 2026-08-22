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
  if ! bash "${REPO_ROOT}/scripts/verify.sh" > /tmp/stremio-mute-install-verify-a.out 2>&1; then
    cat /tmp/stremio-mute-install-verify-a.out >&2
    exit 1
  fi
  if ! grep -Fq 'STATUS: CONFIGURED' /tmp/stremio-mute-install-verify-a.out; then
    cat /tmp/stremio-mute-install-verify-a.out >&2
    printf '%s\n' '[FAIL] First install did not produce CONFIGURED.' >&2
    exit 1
  fi
  bash "${REPO_ROOT}/scripts/install.sh"
  if ! bash "${REPO_ROOT}/scripts/verify.sh" > /tmp/stremio-mute-install-verify-b.out 2>&1; then
    cat /tmp/stremio-mute-install-verify-b.out >&2
    exit 1
  fi
  if ! grep -Fq 'STATUS: CONFIGURED' /tmp/stremio-mute-install-verify-b.out; then
    cat /tmp/stremio-mute-install-verify-b.out >&2
    printf '%s\n' '[FAIL] Reinstall did not produce CONFIGURED.' >&2
    exit 1
  fi
  bash "${REPO_ROOT}/scripts/rollback.sh"
  STOCK_SERVER_PATH=$(flatpak run --command=node "com.stremio.Stremio" -e 'process.stdout.write(process.env.SERVER_PATH || "")')
  if [ "${STOCK_SERVER_PATH}" != '/app/libexec/stremio/server.js' ]; then
    printf '%s\n' "[FAIL] Stock SERVER_PATH was not restored: ${STOCK_SERVER_PATH:-<missing>}" >&2
    exit 1
  fi
  if [ -e "${HOME}/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js" ] || [ -e "${HOME}/.stremio-server/server-wrapper.js" ]; then
    printf '%s\n' '[FAIL] Mute wrapper remains after rollback.' >&2
    exit 1
  fi
  if bash "${REPO_ROOT}/scripts/verify.sh" >/tmp/stremio-mute-rollback-verify.out 2>&1; then
    printf '%s\n' '[FAIL] verify.sh unexpectedly passed after rollback.' >&2
    cat /tmp/stremio-mute-rollback-verify.out >&2
    exit 1
  fi
  if ! grep -Fq 'STATUS: NOT INSTALLED' /tmp/stremio-mute-rollback-verify.out; then
    cat /tmp/stremio-mute-rollback-verify.out >&2
    printf '%s\n' '[FAIL] Rollback did not produce NOT INSTALLED.' >&2
    exit 1
  fi
else
  printf '%s\n' '[Mode] Flatpak unavailable; running isolated lifecycle mock coverage.'
  bash "${REPO_ROOT}/tests/static/test_absolute_path.sh"
  bash "${REPO_ROOT}/tests/static/test_stale_process_install.sh"
fi

printf '%s\n' ''
printf '%s\n' '================================================================================'
printf '%s\n' ' INSTALLER LIFECYCLE INTEGRATION TESTS PASSED'
printf '%s\n' '================================================================================'
