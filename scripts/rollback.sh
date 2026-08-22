#!/usr/bin/env bash
# scripts/rollback.sh — Stremio Mute Rollback & Uninstaller
# Restore stock SERVER_PATH, then remove project-managed wrapper files.

set -euo pipefail

APP_ID="com.stremio.Stremio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=runtime-path.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/runtime-path.sh"

printf '%s\n' '================================================================================'
printf '%s\n' ' STREMIO MUTE — ROLLBACK'
printf '%s\n' '================================================================================'

if ! command -v flatpak >/dev/null 2>&1; then
  printf '%s\n' '  [ERROR] Flatpak CLI is required to restore the stock Stremio server path.' >&2
  printf '%s\n' '  [SAFE] Wrapper files were preserved; no rollback cleanup was performed.' >&2
  exit 1
fi

if ! flatpak info "${APP_ID}" >/dev/null 2>&1; then
  printf '%s\n' "  [ERROR] ${APP_ID} is not installed via Flatpak." >&2
  printf '%s\n' '  [SAFE] Wrapper files were preserved; no rollback cleanup was performed.' >&2
  exit 1
fi

ORIGINAL_OVERRIDE_SHOW=$(flatpak override --user --show "${APP_ID}" 2>/dev/null) || {
  printf '%s\n' '  [ERROR] Could not read the existing Flatpak user override.' >&2
  printf '%s\n' '  [SAFE] Wrapper files were preserved; no rollback cleanup was performed.' >&2
  exit 1
}
ORIGINAL_SERVER_PATH=$(printf '%s\n' "${ORIGINAL_OVERRIDE_SHOW}" | grep -oE 'SERVER_PATH=[^[:space:]]+' | tail -n 1 | cut -d= -f2- || true)
restore_previous_server_path() {
  if [ -n "${ORIGINAL_SERVER_PATH}" ] && [ "${ORIGINAL_SERVER_PATH}" != "${STOCK_SERVER_PATH}" ]; then
    if flatpak override --user --env="SERVER_PATH=${ORIGINAL_SERVER_PATH}" "${APP_ID}" >/dev/null 2>&1; then
      printf '%s\n' "  [SAFE] Previous SERVER_PATH restored: ${ORIGINAL_SERVER_PATH}" >&2
    else
      printf '%s\n' '  [WARN] Previous SERVER_PATH could not be restored; stock path remains selected.' >&2
    fi
  fi
}
fail_before_cleanup() {
  restore_previous_server_path
  printf '%s\n' '  [SAFE] Wrapper files were preserved; no rollback cleanup was performed.' >&2
  exit 1
}

printf '%s\n' "[1/4] Stopping any running ${APP_ID} process..."
RUNNING_APPS=$(flatpak ps --columns=application 2>/dev/null) || {
  printf '%s\n' '  [ERROR] Could not inspect running Flatpak applications.' >&2
  printf '%s\n' '  [SAFE] Wrapper files were preserved; no rollback cleanup was performed.' >&2
  exit 1
}
if printf '%s\n' "${RUNNING_APPS}" | grep -Fxq "${APP_ID}"; then
  if flatpak kill "${APP_ID}"; then
    printf '%s\n' '  [PASS] Running Stremio process stopped.'
  else
    printf '%s\n' '  [ERROR] Could not stop the running Stremio process.' >&2
    printf '%s\n' '  [SAFE] Wrapper files were preserved; no rollback cleanup was performed.' >&2
    exit 1
  fi
else
  printf '%s\n' '  [INFO] No running Stremio process detected.'
fi

printf '%s\n' "[2/5] Verifying stock server target inside the Flatpak sandbox..."
STOCK_TARGET_VISIBLE=$(flatpak run --command=node --env="STREMIO_MUTE_PROBE_PATH=${STOCK_SERVER_PATH}" "${APP_ID}" -e '
const fs = require("fs");
try { fs.accessSync(process.env.STREMIO_MUTE_PROBE_PATH, fs.constants.R_OK); console.log("VISIBLE"); }
catch (err) { console.log("NOT_VISIBLE"); process.exit(1); }
' 2>/dev/null) || {
  printf '%s\n' '  [ERROR] Stock Stremio server is not readable inside the Flatpak sandbox.' >&2
  printf '%s\n' '  [SAFE] Wrapper files were preserved; no rollback cleanup was performed.' >&2
  exit 1
}
if [ "${STOCK_TARGET_VISIBLE}" != 'VISIBLE' ]; then
  printf '%s\n' "  [ERROR] Stock Stremio server target is unavailable: ${STOCK_SERVER_PATH}" >&2
  printf '%s\n' '  [SAFE] Wrapper files were preserved; no rollback cleanup was performed.' >&2
  exit 1
fi
printf '%s\n' "  [PASS] Stock server target is readable: ${STOCK_SERVER_PATH}"

printf '%s\n' "[3/5] Restoring stock SERVER_PATH=${STOCK_SERVER_PATH}..."
if ! flatpak override --user --env="SERVER_PATH=${STOCK_SERVER_PATH}" "${APP_ID}" >/dev/null 2>&1; then
  printf '%s\n' '  [ERROR] Could not restore the stock SERVER_PATH override.' >&2
  fail_before_cleanup
fi

OVERRIDE_SHOW=$(flatpak override --user --show "${APP_ID}" 2>/dev/null) || {
  printf '%s\n' '  [ERROR] Could not read back the Flatpak user override.' >&2
  fail_before_cleanup
}
ACTUAL_SERVER_PATH=$(printf '%s\n' "${OVERRIDE_SHOW}" | grep -oE 'SERVER_PATH=[^[:space:]]+' | tail -n 1 | cut -d= -f2- || true)
if [ "${ACTUAL_SERVER_PATH}" != "${STOCK_SERVER_PATH}" ]; then
  printf '%s\n' "  [ERROR] Flatpak override does not contain the stock path: ${ACTUAL_SERVER_PATH:-<missing>}" >&2
  fail_before_cleanup
fi
if printf '%s\n' "${OVERRIDE_SHOW}" | grep -Fq "${CANONICAL_WRAPPER}" || printf '%s\n' "${OVERRIDE_SHOW}" | grep -Fq "${LEGACY_WRAPPER}"; then
  printf '%s\n' '  [ERROR] A Mute wrapper path remains selectable in the Flatpak override.' >&2
  fail_before_cleanup
fi
printf '%s\n' '  [PASS] Flatpak user override points to the stock server.'

printf '%s\n' '[4/5] Verifying the effective SERVER_PATH inside the Flatpak sandbox...'
EFFECTIVE_SERVER_PATH=$(flatpak run --command=node "${APP_ID}" -e 'process.stdout.write(process.env.SERVER_PATH || "")' 2>/dev/null) || {
  printf '%s\n' '  [ERROR] Could not inspect SERVER_PATH inside the Flatpak sandbox.' >&2
  fail_before_cleanup
}
if [ "${EFFECTIVE_SERVER_PATH}" != "${STOCK_SERVER_PATH}" ]; then
  printf '%s\n' "  [ERROR] Effective SERVER_PATH is not stock: ${EFFECTIVE_SERVER_PATH:-<missing>}" >&2
  fail_before_cleanup
fi
printf '%s\n' "  [PASS] Effective sandbox SERVER_PATH=${EFFECTIVE_SERVER_PATH}"

printf '%s\n' '[5/5] Removing project-managed wrapper files and verifying clean rollback...'
for wrapper in "${CANONICAL_WRAPPER}" "${LEGACY_WRAPPER}"; do
  if [ -L "${wrapper}" ]; then
    rm -f "${wrapper}"
    printf '%s\n' "  [PASS] Removed symlink: ${wrapper}"
  elif [ -f "${wrapper}" ]; then
    rm -f "${wrapper}"
    printf '%s\n' "  [PASS] Removed: ${wrapper}"
  else
    printf '%s\n' "  [INFO] Not present: ${wrapper}"
  fi
done

ERRORS=0
FINAL_OVERRIDE_SHOW=$(flatpak override --user --show "${APP_ID}" 2>/dev/null || true)
FINAL_SERVER_PATH=$(printf '%s\n' "${FINAL_OVERRIDE_SHOW}" | grep -oE 'SERVER_PATH=[^[:space:]]+' | tail -n 1 | cut -d= -f2- || true)
if [ "${FINAL_SERVER_PATH}" = "${STOCK_SERVER_PATH}" ]; then
  printf '%s\n' "  [PASS] Flatpak SERVER_PATH remains stock: ${FINAL_SERVER_PATH}"
else
  printf '%s\n' '  [FAIL] Flatpak SERVER_PATH is no longer the stock path.' >&2
  ERRORS=$((ERRORS+1))
fi
for wrapper in "${CANONICAL_WRAPPER}" "${LEGACY_WRAPPER}"; do
  if [ -e "${wrapper}" ] || [ -L "${wrapper}" ]; then
    printf '%s\n' "  [FAIL] Project-managed wrapper remains at: ${wrapper}" >&2
    ERRORS=$((ERRORS+1))
  else
    printf '%s\n' "  [PASS] Project-managed wrapper absent: ${wrapper}"
  fi
done

printf '%s\n' '================================================================================'
if [ "${ERRORS}" -eq 0 ]; then
  printf '%s\n' ' ROLLBACK SUCCESSFUL'
  printf '%s\n' ' Stremio is configured to use its stock server; Stremio Mute is removed.'
  printf '%s\n' '================================================================================'
  exit 0
fi
printf '%s\n' " ROLLBACK FAILED: ${ERRORS} residual conditions remain." >&2
printf '%s\n' '================================================================================'
exit 1
