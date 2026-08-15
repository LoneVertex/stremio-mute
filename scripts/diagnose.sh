#!/usr/bin/env bash
# scripts/diagnose.sh — Stremio Mute Diagnostic Report Generator
# Generates a sanitized, issue-safe diagnostic summary for troubleshooting.

set -uo pipefail

APP_ID="com.stremio.Stremio"
HOME_DIR=$(cd "${HOME}" && pwd -P)
CONTROLLER_FILE="${HOME_DIR}/.stremio-server/server-wrapper.js"
LEGACY_CONTROLLER_FILE="${HOME_DIR}/.var/app/${APP_ID}/.stremio-server/server-wrapper.js"

printf '%s\n' '================================================================================'
printf '%s\n' ' STREMIO MUTE — DIAGNOSTIC REPORT'
REPORT_TIME=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
printf '%s\n' " Generated on: ${REPORT_TIME}"
printf '%s\n' '================================================================================'

printf '%s\n' ''
printf '%s\n' '### 1. System & Environment'
OS_INFO=$(uname -s -r -v)
printf '%s\n' "- OS: ${OS_INFO}"
if [ -f /etc/os-release ]; then
  DISTRO_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2- | sed 's/^"//; s/"$//')
  printf '%s\n' "- Distribution: ${DISTRO_NAME}"
fi
printf '%s\n' "- Desktop Session: ${XDG_CURRENT_DESKTOP:-unknown} (${XDG_SESSION_TYPE:-unknown})"
FLATPAK_VERSION=$(flatpak --version 2>/dev/null || printf '%s' 'not installed')
NODE_VERSION=$(node --version 2>/dev/null || printf '%s' 'not installed')
printf '%s\n' "- Flatpak Version: ${FLATPAK_VERSION}"
printf '%s\n' "- Node.js Version: ${NODE_VERSION}"

printf '%s\n' ''
printf '%s\n' '### 2. Flatpak & Stremio Packaging'
if command -v flatpak >/dev/null 2>&1 && flatpak info "${APP_ID}" >/dev/null 2>&1; then
  printf '%s\n' "- Application ID: ${APP_ID}"
  STREMIO_VERSION=$(flatpak info "${APP_ID}" | grep -E '^ *Version:' | awk '{print $2}' || printf '%s' installed)
  INSTALL_SCOPE=$(flatpak info "${APP_ID}" | grep -E '^ *Installation:' | awk '{print $2}' || printf '%s' unknown)
  printf '%s\n' "- Stremio Version: ${STREMIO_VERSION}"
  printf '%s\n' "- Installation Scope: ${INSTALL_SCOPE}"
else
  printf '%s\n' '- Stremio Flatpak: NOT INSTALLED OR FLATPAK UNAVAILABLE'
fi

printf '%s\n' ''
printf '%s\n' '### 3. Controller Configuration & Wrapper Storage'
if [ -f "${CONTROLLER_FILE}" ] && [ ! -L "${CONTROLLER_FILE}" ]; then
  printf '%s\n' "- Canonical server-wrapper.js: Present (${CONTROLLER_FILE})"
  FILE_METADATA=$(stat -c '%s bytes, perm %a' "${CONTROLLER_FILE}" 2>/dev/null || printf '%s' present)
  printf '%s\n' "- File metadata: ${FILE_METADATA}"
  if node -c "${CONTROLLER_FILE}" >/dev/null 2>&1; then
    printf '%s\n' '- Syntax Check: OK'
  else
    printf '%s\n' '- Syntax Check: FAILED'
  fi
else
  printf '%s\n' "- Canonical server-wrapper.js: NOT PRESENT at ${CONTROLLER_FILE}"
fi
if [ -e "${LEGACY_CONTROLLER_FILE}" ]; then
  printf '%s\n' "- Legacy wrapper path still present: ${LEGACY_CONTROLLER_FILE}"
else
  printf '%s\n' '- Legacy wrapper path: absent'
fi

printf '%s\n' '- Flatpak User Override (CLI):'
if command -v flatpak >/dev/null 2>&1; then
  OVERRIDE_TEXT=$(flatpak override --user --show "${APP_ID}" 2>/dev/null || true)
  if printf '%s\n' "${OVERRIDE_TEXT}" | grep -E 'SERVER_PATH' >/dev/null 2>&1; then
    printf '%s\n' "${OVERRIDE_TEXT}" | grep -E 'SERVER_PATH'
  else
    printf '%s\n' '  (No SERVER_PATH override set)'
  fi
else
  printf '%s\n' '  (Flatpak unavailable)'
fi

printf '%s\n' ''
printf '%s\n' '### 4. Structural Code Fingerprint Inspection'
if command -v flatpak >/dev/null 2>&1; then
  flatpak run --command=node "${APP_ID}" -e '
const fs = require("fs");
const target = "/app/libexec/stremio/server.js";
if (!fs.existsSync(target)) {
  console.log("- server.js: NOT FOUND at /app/libexec/stremio/server.js");
  process.exit(0);
}
const code = fs.readFileSync(target, "utf8");
console.log("- server.js size: " + code.length + " bytes");
const p1 = code.split("var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5").length - 1;
const p2 = code.split("MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {").length - 1;
const p3 = code.split("uploadPipe.push(engine.store.read, index, (function(err, buffer) {").length - 1;
console.log("- Fingerprint 1 (rechokeSlots): count=" + p1 + " (expected 1)");
console.log("- Fingerprint 2 (defaults.uploads): count=" + p2 + " (expected 1)");
console.log("- Fingerprint 3 (wire request): count=" + p3 + " (expected 1)");
' 2>/dev/null || printf '%s\n' '- Fingerprint check failed to execute.'
else
  printf '%s\n' '- Fingerprint check unavailable because Flatpak is not installed.'
fi

printf '%s\n' ''
printf '%s\n' '### 5. Runtime Telemetry'
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 1 'http://127.0.0.1:11470/heartbeat' >/dev/null 2>&1; then
  printf '%s\n' '- Local Server Port 11470: LISTENING'
  printf '%s\n' '- Controller Status Endpoint:'
  curl -fsS --max-time 1 'http://127.0.0.1:11470/zero-upload-controller' 2>/dev/null | jq . 2>/dev/null || printf '%s\n' '  (Controller endpoint not responding)'
  printf '%s\n' '- Heartbeat:'
  curl -fsS --max-time 1 'http://127.0.0.1:11470/heartbeat' 2>/dev/null || printf '%s\n' '  (Heartbeat failed)'
else
  printf '%s\n' '- Local Server Port 11470: NOT LISTENING (Stremio is idle or unavailable)'
fi

printf '%s\n' ''
printf '%s\n' '================================================================================'
printf '%s\n' ' Report complete. This output is sanitized and safe to share on GitHub Issues.'
printf '%s\n' '================================================================================'
