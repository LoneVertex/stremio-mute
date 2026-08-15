#!/usr/bin/env bash
# scripts/rollback.sh — Stremio Mute Rollback & Uninstaller
# Removes the exact SERVER_PATH override and project-managed wrapper files idempotently.

set -euo pipefail

APP_ID="com.stremio.Stremio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=runtime-path.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/runtime-path.sh"

printf '%s\n' '================================================================================'
printf '%s\n' ' STREMIO MUTE — ROLLBACK'
printf '%s\n' '================================================================================'

printf '%s\n' "[1/3] Stopping any running ${APP_ID} process..."
if command -v flatpak >/dev/null 2>&1 && flatpak ps --columns=application 2>/dev/null | grep -Fxq "${APP_ID}"; then
  flatpak kill "${APP_ID}"
  printf '%s\n' '  [PASS] Running Stremio process stopped.'
else
  printf '%s\n' '  [INFO] No running Stremio process detected or Flatpak CLI unavailable.'
fi

printf '%s\n' "[2/3] Removing SERVER_PATH override for ${APP_ID}..."
if command -v flatpak >/dev/null 2>&1; then
  if flatpak override --user --unset-env=SERVER_PATH "${APP_ID}" >/dev/null 2>&1; then
    printf '%s\n' '  [PASS] SERVER_PATH override unset via Flatpak CLI.'
  else
    printf '%s\n' '  [INFO] No active Flatpak CLI override found or already cleared.'
  fi
else
  printf '%s\n' '  [INFO] Flatpak CLI unavailable; checking local override file only.'
fi

if [ -f "${OVERRIDE_FILE}" ] && grep -q '^SERVER_PATH=' "${OVERRIDE_FILE}" 2>/dev/null; then
  sed -i '/^SERVER_PATH=/d' "${OVERRIDE_FILE}"
  printf '%s\n' '  [PASS] Removed SERVER_PATH from the user override file.'
fi

printf '%s\n' '[3/3] Removing project-managed wrapper files and verifying clean rollback...'
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
if command -v flatpak >/dev/null 2>&1; then
  OVERRIDE_SHOW=$(flatpak override --user --show "${APP_ID}" 2>/dev/null || true)
  if printf '%s\n' "${OVERRIDE_SHOW}" | grep -qE '(^|[[:space:]])SERVER_PATH='; then
    printf '%s\n' '  [FAIL] SERVER_PATH override remains active.' >&2
    ERRORS=$((ERRORS+1))
  else
    printf '%s\n' '  [PASS] Flatpak SERVER_PATH override is absent.'
  fi
fi
if [ -f "${OVERRIDE_FILE}" ] && grep -q '^SERVER_PATH=' "${OVERRIDE_FILE}" 2>/dev/null; then
  printf '%s\n' '  [FAIL] Local override file still contains SERVER_PATH.' >&2
  ERRORS=$((ERRORS+1))
else
  printf '%s\n' '  [PASS] Local override file has no SERVER_PATH entry.'
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
  printf '%s\n' ' Stremio has been restored to its stock configuration.'
  printf '%s\n' '================================================================================'
  exit 0
fi
printf '%s\n' " ROLLBACK FAILED: ${ERRORS} residual artifacts remain." >&2
printf '%s\n' '================================================================================'
exit 1
