#!/usr/bin/env bash
# scripts/rollback.sh — Revert Stremio to Standard Default Configuration
# Removes Flatpak user override and deletes the sandboxed server wrapper.

set -euo pipefail

SANDBOX_WRAPPER="${HOME}/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js"
OVERRIDE_FILE="${HOME}/.local/share/flatpak/overrides/com.stremio.Stremio"

echo "================================================================================"
echo " STREMIO ZERO-UPLOAD CONTROLLER — ROLLBACK"
echo "================================================================================"

# 1. Remove Flatpak override
echo "[1/2] Removing Flatpak SERVER_PATH environment override..."
if command -v flatpak &>/dev/null; then
  flatpak override --user --unset-env=SERVER_PATH com.stremio.Stremio || true
fi

# 2. Remove installed wrapper
echo "[2/2] Removing installed server-wrapper.js..."
rm -f "$SANDBOX_WRAPPER"

# 3. Verify clean uninstallation
echo ""
echo "── Verification ────────────────────────────────────────────────────────────"
ERRORS=0

# Verify override removal
OVERRIDE_CHECK=""
if [ -f "$OVERRIDE_FILE" ]; then
  OVERRIDE_CHECK=$(grep -E "^SERVER_PATH=" "$OVERRIDE_FILE" 2>/dev/null || true)
fi

if [ -n "$OVERRIDE_CHECK" ]; then
  echo "  [FAIL] Flatpak SERVER_PATH override is still present: $OVERRIDE_CHECK" >&2
  ERRORS=$((ERRORS+1))
else
  echo "  [PASS] Flatpak SERVER_PATH override successfully removed."
fi

# Verify wrapper file removal
if [ -f "$SANDBOX_WRAPPER" ]; then
  echo "  [FAIL] server-wrapper.js still exists at: $SANDBOX_WRAPPER" >&2
  ERRORS=$((ERRORS+1))
else
  echo "  [PASS] server-wrapper.js successfully removed."
fi

echo ""
echo "================================================================================"
if [ "$ERRORS" -eq 0 ]; then
  echo " ROLLBACK SUCCESSFUL"
  echo " Stremio is restored to stock configuration."
  echo "================================================================================"
  exit 0
else
  echo " ROLLBACK INCOMPLETE ($ERRORS errors detected)." >&2
  echo "================================================================================"
  exit 1
fi
