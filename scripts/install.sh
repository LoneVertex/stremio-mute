#!/usr/bin/env bash
# scripts/install.sh — Stremio Mute Installer
# Hardened Pre-Flight Architecture:
# 1. Detect prerequisites -> 2. Inspect Stremio -> 3. Validate Compatibility ->
# 4. Validate Wrapper -> 5. Stage Wrapper -> 6. Apply Override -> 7. Verify.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WRAPPER_SRC="${REPO_ROOT}/src/server-wrapper.js"
APP_ID="com.stremio.Stremio"
SANDBOX_DIR="${HOME}/.var/app/${APP_ID}/.stremio-server"
TARGET_WRAPPER="${SANDBOX_DIR}/server-wrapper.js"

echo "================================================================================"
echo " STREMIO MUTE — INSTALLER"
echo " Tagline: Mute BitTorrent peer uploads. Keep streaming."
echo "================================================================================"

# 1. Detect Prerequisites
echo "[1/7] Detecting system prerequisites..."
if ! command -v flatpak &>/dev/null; then
  echo "  [ERROR] 'flatpak' command not found. Flatpak is required." >&2
  exit 1
fi
echo "  [PASS] Flatpak CLI detected."

# 2. Inspect Stremio Flatpak
echo "[2/7] Inspecting Flatpak installation for ${APP_ID}..."
if ! flatpak info "${APP_ID}" &>/dev/null; then
  echo "  [ERROR] ${APP_ID} is not installed via Flatpak." >&2
  echo "  Please install it first with: flatpak install flathub ${APP_ID}" >&2
  exit 1
fi
echo "  [PASS] ${APP_ID} Flatpak installation confirmed."

# 3. Pre-Flight Compatibility Validation (Must validate BEFORE activation)
echo "[3/7] Running pre-flight compatibility check against Stremio engine..."
COMPAT_CHECK=$(flatpak run --command=node "${APP_ID}" -e '
const fs = require("fs");
const target = "/app/libexec/stremio/server.js";
if (!fs.existsSync(target)) {
  console.log("ERR_NOT_FOUND");
  process.exit(1);
}
const code = fs.readFileSync(target, "utf8");
const p1 = (code.split("var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5").length - 1) === 1;
const p2 = (code.split("MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {").length - 1) === 1;
const p3 = (code.split("uploadPipe.push(engine.store.read, index, (function(err, buffer) {").length - 1) === 1;

if (p1 && p2 && p3) {
  console.log("COMPAT_OK");
  process.exit(0);
} else {
  console.log("COMPAT_FAIL: p1=" + p1 + " p2=" + p2 + " p3=" + p3);
  process.exit(2);
}
' 2>/dev/null || echo "COMPAT_ERR")

if [ "${COMPAT_CHECK}" != "COMPAT_OK" ]; then
  echo "  [FATAL] Pre-flight compatibility validation failed: ${COMPAT_CHECK}" >&2
  echo "  Stremio server.js structural code does not match expected fingerprints." >&2
  echo "  Installation aborted BEFORE making any changes to prevent disruption." >&2
  exit 2
fi
echo "  [PASS] Stremio server.js structural fingerprints verified compatible (exact-1 match)."

# 4. Validate Wrapper File Presence
echo "[4/7] Validating wrapper source file..."
if [ ! -f "${WRAPPER_SRC}" ]; then
  echo "  [ERROR] Source wrapper missing at: ${WRAPPER_SRC}" >&2
  exit 1
fi
echo "  [PASS] Source wrapper present at: ${WRAPPER_SRC}"

# 5. Stage Wrapper into Sandbox Storage
echo "[5/7] Staging server-wrapper.js into Stremio sandbox storage..."
mkdir -p "${SANDBOX_DIR}"
install -m 0644 "${WRAPPER_SRC}" "${TARGET_WRAPPER}"
echo "  [PASS] Staged: ${TARGET_WRAPPER} (mode 0644)"

# 6. Apply Flatpak User Environment Override
echo "[6/7] Applying Flatpak user environment override..."
flatpak override --user --env=SERVER_PATH="~/.stremio-server/server-wrapper.js" "${APP_ID}"
echo "  [PASS] Override set: SERVER_PATH=~/.stremio-server/server-wrapper.js"

# 7. Run Verification Check
echo "[7/7] Running operational verification check..."
bash "${SCRIPT_DIR}/verify.sh"

echo "================================================================================"
echo " INSTALLATION SUCCESSFUL"
echo "================================================================================"
echo " Staged:   ${TARGET_WRAPPER}"
echo " Override: SERVER_PATH=~/.stremio-server/server-wrapper.js"
echo " Status:   Stremio Mute is ready and will enforce upload policy when Stremio is opened."
echo " Verify:   Run './scripts/verify.sh' at any time to inspect operational health."
echo "================================================================================"
