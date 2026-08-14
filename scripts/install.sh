#!/usr/bin/env bash
# scripts/install.sh — Production Installer for Stremio Zero-Upload Controller
# Installs server-wrapper.js to persistent sandbox directory and configures Flatpak user override.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WRAPPER_SRC="${REPO_ROOT}/src/server-wrapper.js"
SANDBOX_DIR="${HOME}/.var/app/com.stremio.Stremio/.stremio-server"
TARGET_WRAPPER="${SANDBOX_DIR}/server-wrapper.js"
SANDBOX_ENV_PATH="${HOME}/.stremio-server/server-wrapper.js"

echo "================================================================================"
echo " STREMIO ZERO-UPLOAD CONTROLLER — INSTALLER"
echo "================================================================================"

# 1. Source verification
if [ ! -f "$WRAPPER_SRC" ]; then
  echo "[ERROR] Source wrapper file not found at: $WRAPPER_SRC" >&2
  exit 1
fi

# 2. Flatpak installation check
if ! command -v flatpak &>/dev/null; then
  echo "[ERROR] flatpak CLI is not installed on this system." >&2
  exit 1
fi

if ! flatpak info com.stremio.Stremio &>/dev/null; then
  echo "[ERROR] Flatpak package 'com.stremio.Stremio' is not installed." >&2
  echo "        Please install Stremio first: flatpak install flathub com.stremio.Stremio" >&2
  exit 1
fi

# 3. Create persistent sandbox directory
echo "[1/4] Ensuring sandbox storage directory exists..."
mkdir -p "$SANDBOX_DIR"

# 4. Install wrapper
echo "[2/4] Installing server-wrapper.js..."
install -m 644 "$WRAPPER_SRC" "$TARGET_WRAPPER"

# 5. Apply Flatpak environment override
echo "[3/4] Configuring Flatpak user environment override..."
flatpak override --user --env="SERVER_PATH=${SANDBOX_ENV_PATH}" com.stremio.Stremio

# 6. Post-install verification
echo "[4/4] Running static verification..."
if bash "${SCRIPT_DIR}/verify.sh" --quiet 2>/dev/null || bash "${SCRIPT_DIR}/verify.sh"; then
  echo ""
  echo "================================================================================"
  echo " INSTALLATION SUCCESSFUL"
  echo "================================================================================"
  echo " Installed: $TARGET_WRAPPER"
  echo " Override:  SERVER_PATH=${SANDBOX_ENV_PATH}"
  echo " Status:    Zero-upload controller is configured and will activate upon Stremio launch."
  echo " Verify:    Run './scripts/verify.sh' at any time to inspect operational health."
  echo "================================================================================"
  exit 0
else
  echo ""
  echo "[ERROR] Post-installation health check failed. Review errors above." >&2
  exit 1
fi
