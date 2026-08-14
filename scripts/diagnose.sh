#!/usr/bin/env bash
# scripts/diagnose.sh — Redacted, Issue-Safe System Diagnostics
# Collects relevant environment metadata for GitHub issue reports without leaking private data.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "================================================================================"
echo " STREMIO ZERO-UPLOAD CONTROLLER — SYSTEM DIAGNOSTICS"
echo " (Safe for sharing in GitHub issues — all paths and tokens are redacted)"
echo "================================================================================"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "── 1. Host Environment ─────────────────────────────────────────────────────────"
if [ -f /etc/os-release ]; then
  OS_NAME=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
  echo "OS:             ${OS_NAME:-Linux}"
else
  echo "OS:             $(uname -s)"
fi
echo "Kernel:         $(uname -r) ($(uname -m))"
echo "Desktop:        ${XDG_CURRENT_DESKTOP:-Unknown} (${XDG_SESSION_TYPE:-Unknown})"

echo ""
echo "── 2. Flatpak & Stremio Environment ────────────────────────────────────────────"
if command -v flatpak &>/dev/null; then
  echo "Flatpak CLI:    $(flatpak --version 2>/dev/null || echo 'Installed')"
  if flatpak info com.stremio.Stremio &>/dev/null; then
    FLATPAK_VER=$(flatpak info com.stremio.Stremio 2>/dev/null | grep "^Version:" | awk '{print $2}' || echo "Installed")
    FLATPAK_BRANCH=$(flatpak info com.stremio.Stremio 2>/dev/null | grep "^Branch:" | awk '{print $2}' || echo "stable")
    FLATPAK_ARCH=$(flatpak info com.stremio.Stremio 2>/dev/null | grep "^Arch:" | awk '{print $2}' || echo "x86_64")
    echo "Stremio Flatpak: Version ${FLATPAK_VER} (${FLATPAK_BRANCH}, ${FLATPAK_ARCH})"
  else
    echo "Stremio Flatpak: NOT INSTALLED"
  fi
else
  echo "Flatpak CLI:    NOT INSTALLED"
fi

echo ""
echo "── 3. Controller Configuration ─────────────────────────────────────────────────"
WRAPPER_FILE="${HOME}/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js"
OVERRIDE_FILE="${HOME}/.local/share/flatpak/overrides/com.stremio.Stremio"

if [ -f "$WRAPPER_FILE" ]; then
  CTRL_VER=$(grep "CONTROLLER_VERSION = " "$WRAPPER_FILE" 2>/dev/null | head -1 | cut -d"'" -f2 || echo "1.2.0")
  WRAPPER_HASH=$(sha256sum "$WRAPPER_FILE" 2>/dev/null | awk '{print $1}')
  PERMS=$(stat -c "%a" "$WRAPPER_FILE" 2>/dev/null || echo "unknown")
  echo "Wrapper File:   Present (${PERMS}, sha256: ${WRAPPER_HASH})"
  echo "Controller Ver: ${CTRL_VER}"
else
  echo "Wrapper File:   NOT INSTALLED"
fi

if [ -f "$OVERRIDE_FILE" ]; then
  SERVER_ENV=$(grep "^SERVER_PATH=" "$OVERRIDE_FILE" 2>/dev/null || true)
  # Sanitize user home path
  SANITIZED_ENV=$(echo "$SERVER_ENV" | sed "s|/home/[^/]*|~|g")
  echo "Override State: ${SANITIZED_ENV:-None}"
else
  echo "Override State: None"
fi

echo ""
echo "── 4. Structural Compatibility Check ───────────────────────────────────────────"
if flatpak info com.stremio.Stremio &>/dev/null; then
  FP_RESULT=$(flatpak run --command=node com.stremio.Stremio -e "
const fs = require('fs');
try {
  const code = fs.readFileSync('/app/libexec/stremio/server.js', 'utf8');
  const p1 = 'var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5';
  const p2 = 'MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {';
  const p3 = 'uploadPipe.push(engine.store.read, index, (function(err, buffer) {';
  const c1 = code.split(p1).length - 1;
  const c2 = code.split(p2).length - 1;
  const c3 = code.split(p3).length - 1;
  console.log(JSON.stringify({ rechokeSlots: c1, getDefaults: c2, wireRequest: c3, verified: (c1===1 && c2===1 && c3===1) }));
} catch(e) { console.log(JSON.stringify({ error: e.message })); }
" 2>/dev/null || echo '{"error":"flatpak_node_failed"}')
  echo "Fingerprints:   $FP_RESULT"
else
  echo "Fingerprints:   N/A (Stremio not installed)"
fi

echo ""
echo "── 5. Runtime Telemetry Status ─────────────────────────────────────────────────"
CTRL_RESP=$(curl -s --max-time 1 http://127.0.0.1:11470/zero-upload-controller 2>/dev/null || echo "{}")
if echo "$CTRL_RESP" | grep -q '"active":true'; then
  echo "Server State:   RUNNING (Zero-Upload Controller Active)"
  echo "Controller IPC: $(echo "$CTRL_RESP" | jq -c '{active: .active, version: .version, policy: .policy}' 2>/dev/null || echo "$CTRL_RESP")"
else
  HB_RESP=$(curl -s --max-time 1 http://127.0.0.1:11470/heartbeat 2>/dev/null || echo "{}")
  if echo "$HB_RESP" | grep -q '"success":true'; then
    echo "Server State:   RUNNING (Stock Server Detected — Controller Inactive!)"
  else
    echo "Server State:   STOPPED / IDLE"
  fi
fi

echo ""
echo "================================================================================"
echo " Diagnostics complete. Copy output above when filing a GitHub issue."
echo "================================================================================"
