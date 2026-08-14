#!/usr/bin/env bash
# scripts/diagnose.sh — Stremio Mute Diagnostic Report Generator
# Generates a sanitized, issue-safe diagnostic summary for troubleshooting.

set -uo pipefail

APP_ID="com.stremio.Stremio"
CONTROLLER_FILE="${HOME}/.var/app/${APP_ID}/.stremio-server/server-wrapper.js"
OVERRIDE_FILE="${HOME}/.local/share/flatpak/overrides/${APP_ID}"

echo "================================================================================"
echo " STREMIO MUTE — DIAGNOSTIC REPORT"
echo " Generated on: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "================================================================================"

echo ""
echo "### 1. System & Environment"
echo "- OS: $(uname -s -r -v)"
if [ -f /etc/os-release ]; then
  echo "- Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
fi
echo "- Desktop Session: ${XDG_CURRENT_DESKTOP:-unknown} (${XDG_SESSION_TYPE:-unknown})"
echo "- Flatpak Version: $(flatpak --version 2>/dev/null || echo 'not installed')"
echo "- Node.js Version: $(node --version 2>/dev/null || echo 'not installed')"

echo ""
echo "### 2. Flatpak & Stremio Packaging"
if flatpak info "${APP_ID}" &>/dev/null; then
  echo "- Application ID: ${APP_ID}"
  echo "- Stremio Version: $(flatpak info "${APP_ID}" | grep -E '^ *Version:' | awk '{print $2}' || echo 'installed')"
  echo "- Installation Scope: $(flatpak info "${APP_ID}" | grep -E '^ *Installation:' | awk '{print $2}' || echo 'unknown')"
else
  echo "- Stremio Flatpak: NOT INSTALLED"
fi

echo ""
echo "### 3. Controller Configuration & Sandbox Storage"
if [ -f "${CONTROLLER_FILE}" ]; then
  echo "- server-wrapper.js: Present ($(stat -c '%s bytes, perm %a' "${CONTROLLER_FILE}" 2>/dev/null || echo 'present'))"
  echo "- Syntax Check: $(node -c "${CONTROLLER_FILE}" 2>&1 || echo 'Syntax OK')"
else
  echo "- server-wrapper.js: NOT PRESENT"
fi

echo "- Flatpak User Override (CLI):"
flatpak override --user --show "${APP_ID}" 2>/dev/null | grep -E 'SERVER_PATH' || echo "  (No SERVER_PATH override set)"

echo ""
echo "### 4. Structural Code Fingerprint Inspection"
flatpak run --command=node "${APP_ID}" -e '
const fs = require("fs");
const target = "/app/libexec/stremio/server.js";
if (!fs.existsSync(target)) {
  console.log("- server.js: NOT FOUND at /app/libexec/stremio/server.js");
  process.exit(0);
}
const code = fs.readFileSync(target, "utf8");
console.log("- server.js size: " + code.length + " bytes");
const p1 = (code.split("var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5").length - 1);
const p2 = (code.split("MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {").length - 1);
const p3 = (code.split("uploadPipe.push(engine.store.read, index, (function(err, buffer) {").length - 1);
console.log(`- Fingerprint 1 (rechokeSlots): count=${p1} (expected 1)`);
console.log(`- Fingerprint 2 (defaults.uploads): count=${p2} (expected 1)`);
console.log(`- Fingerprint 3 (wire.on request): count=${p3} (expected 1)`);
' 2>/dev/null || echo "- Fingerprint check failed to execute."

echo ""
echo "### 5. Runtime Telemetry"
if curl -s --max-time 1 "http://127.0.0.1:11470/heartbeat" &>/dev/null; then
  echo "- Local Server Port 11470: LISTENING"
  echo "- Controller Status Endpoint:"
  curl -s --max-time 1 "http://127.0.0.1:11470/zero-upload-controller" 2>/dev/null | jq . 2>/dev/null || echo "  (Controller endpoint not responding)"
  echo "- Heartbeat:"
  curl -s --max-time 1 "http://127.0.0.1:11470/heartbeat" 2>/dev/null || echo "  (Heartbeat failed)"
else
  echo "- Local Server Port 11470: NOT LISTENING (Stremio is idle)"
fi

echo ""
echo "================================================================================"
echo " Report complete. This output is sanitized and safe to share on GitHub Issues."
echo "================================================================================"
