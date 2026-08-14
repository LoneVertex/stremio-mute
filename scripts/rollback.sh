#!/usr/bin/env bash
# scripts/rollback.sh — Stremio Mute Rollback & Uninstaller
# Cleanly removes the Flatpak user environment override and sandboxed wrapper.
# Verified and idempotent.

set -euo pipefail

APP_ID="com.stremio.Stremio"
TARGET_WRAPPER="${HOME}/.var/app/${APP_ID}/.stremio-server/server-wrapper.js"
OVERRIDE_FILE="${HOME}/.local/share/flatpak/overrides/${APP_ID}"

echo "================================================================================"
echo " STREMIO MUTE — ROLLBACK"
echo "================================================================================"

# 1. Unset Flatpak user environment override
echo "[1/3] Removing Flatpak user environment override for ${APP_ID}..."
if flatpak override --user --unset-env=SERVER_PATH "${APP_ID}" 2>/dev/null; then
  echo "  [PASS] SERVER_PATH override unset via Flatpak CLI."
else
  echo "  [INFO] No active Flatpak CLI override found or already cleared."
fi

# Fallback direct override file cleanup if present
if [ -f "${OVERRIDE_FILE}" ] && grep -q "SERVER_PATH=" "${OVERRIDE_FILE}" 2>/dev/null; then
  sed -i '/SERVER_PATH=/d' "${OVERRIDE_FILE}" || true
  echo "  [PASS] Cleaned SERVER_PATH from override file."
fi

# 2. Remove sandboxed wrapper file
echo "[2/3] Removing sandboxed server-wrapper.js..."
if [ -f "${TARGET_WRAPPER}" ]; then
  rm -f "${TARGET_WRAPPER}"
  echo "  [PASS] Removed: ${TARGET_WRAPPER}"
else
  echo "  [INFO] Controller file already removed."
fi

# 3. Active Verification of Clean State
echo "[3/3] Actively verifying clean rollback state..."
ERRORS=0

OVERRIDE_SHOW=$(flatpak override --user --show "${APP_ID}" 2>/dev/null || echo "")
if echo "${OVERRIDE_SHOW}" | grep -q "SERVER_PATH="; then
  echo "  [FAIL] Flatpak override SERVER_PATH is still active!" >&2
  ERRORS=$((ERRORS+1))
else
  echo "  [PASS] Verified: Flatpak environment override is removed."
fi

if [ -f "${TARGET_WRAPPER}" ]; then
  echo "  [FAIL] Controller file still exists at: ${TARGET_WRAPPER}" >&2
  ERRORS=$((ERRORS+1))
else
  echo "  [PASS] Verified: Sandboxed wrapper file is removed."
fi

echo ""
echo "================================================================================"
if [ "$ERRORS" -eq 0 ]; then
  echo " ROLLBACK SUCCESSFUL"
  echo " Stremio has been restored to default stock configuration."
  echo " All addons, library items, and user settings were preserved."
  echo "================================================================================"
  exit 0
else
  echo " ROLLBACK FAILED: ${ERRORS} residual artifacts remain." >&2
  echo "================================================================================"
  exit 1
fi
