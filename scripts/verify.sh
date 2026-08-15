#!/usr/bin/env bash
# scripts/verify.sh — Stremio Mute Operational Health Check
# Authoritative State Semantics:
# NOT INSTALLED | CONFIGURED | RUNTIME VERIFIED | NOT PROTECTED | INCOMPATIBLE | ERROR

set -uo pipefail

APP_ID="com.stremio.Stremio"
CONTROLLER_FILE="${HOME}/.var/app/${APP_ID}/.stremio-server/server-wrapper.js"
EXPECTED_OVERRIDE_VAL="SERVER_PATH=~/.stremio-server/server-wrapper.js"
OVERRIDE_FILE="${HOME}/.local/share/flatpak/overrides/${APP_ID}"

TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNS=0
ERRORS=0

# State flags
STATIC_OK=false
RUNTIME_RUNNING=false
CONTROLLER_RESPONSIVE=false
HEARTBEAT_OK=false
INCOMPATIBLE=false
NOT_INSTALLED=false

echo "================================================================================"
echo " STREMIO MUTE — OPERATIONAL HEALTH CHECK"
echo " Tagline: Mute BitTorrent peer uploads. Keep streaming."
echo "================================================================================"

# ── 1. Controller File & Syntax Integrity ──────────────────────────────────────
echo ""
echo "── 1. Controller File & Syntax Integrity ────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS+1))
if [ -f "${CONTROLLER_FILE}" ]; then
  echo "  [PASS] server-wrapper.js exists in sandbox storage"
  PASSED_CHECKS=$((PASSED_CHECKS+1))
  
  TOTAL_CHECKS=$((TOTAL_CHECKS+1))
  PERMS=$(stat -c "%a" "${CONTROLLER_FILE}" 2>/dev/null || stat -f "%Lp" "${CONTROLLER_FILE}" 2>/dev/null || echo "unknown")
  if [ "$PERMS" = "644" ] || [ "$PERMS" = "755" ]; then
    echo "  [PASS] Permissions are safe (${PERMS})"
    PASSED_CHECKS=$((PASSED_CHECKS+1))
  else
    echo "  [WARN] File permissions are: ${PERMS} (expected 644)"
    WARNS=$((WARNS+1))
  fi

  TOTAL_CHECKS=$((TOTAL_CHECKS+1))
  if node -c "${CONTROLLER_FILE}" 2>/dev/null; then
    echo "  [PASS] server-wrapper.js JavaScript syntax is valid"
    PASSED_CHECKS=$((PASSED_CHECKS+1))
  else
    echo "  [FAIL] server-wrapper.js has JavaScript syntax errors"
    ERRORS=$((ERRORS+1))
  fi
else
  echo "  [FAIL] Controller file missing at: ${CONTROLLER_FILE}"
  ERRORS=$((ERRORS+1))
  NOT_INSTALLED=true
fi

# ── 2. Flatpak Installation & User Override ────────────────────────────────────
echo ""
echo "── 2. Flatpak Installation & User Override ──────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS+1))
if flatpak info "${APP_ID}" &>/dev/null; then
  echo "  [PASS] ${APP_ID} is installed via Flatpak"
  PASSED_CHECKS=$((PASSED_CHECKS+1))
else
  echo "  [FAIL] ${APP_ID} is not installed via Flatpak"
  ERRORS=$((ERRORS+1))
  NOT_INSTALLED=true
fi

TOTAL_CHECKS=$((TOTAL_CHECKS+1))
# Primary source of truth: flatpak override --user --show
OVERRIDE_SHOW=$(flatpak override --user --show "${APP_ID}" 2>/dev/null || echo "")
if echo "${OVERRIDE_SHOW}" | grep -Fxq "${EXPECTED_OVERRIDE_VAL}"; then
  echo "  [PASS] Flatpak user override active and verified (${EXPECTED_OVERRIDE_VAL})"
  PASSED_CHECKS=$((PASSED_CHECKS+1))
elif [ -f "${OVERRIDE_FILE}" ] && grep -Fxq "${EXPECTED_OVERRIDE_VAL}" "${OVERRIDE_FILE}" 2>/dev/null; then
  echo "  [PASS] Flatpak override active (Fallback file check: ${EXPECTED_OVERRIDE_VAL})"
  PASSED_CHECKS=$((PASSED_CHECKS+1))
else
  echo "  [FAIL] Flatpak user environment override for SERVER_PATH is missing or mismatched (expected: ${EXPECTED_OVERRIDE_VAL})"
  ERRORS=$((ERRORS+1))
  NOT_INSTALLED=true
fi

# ── 3. Structural Compatibility Fingerprints ──────────────────────────────────
echo ""
echo "── 3. Structural Compatibility Fingerprints ──────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS+1))
COMPAT_RESULT=$(flatpak run --command=node "${APP_ID}" -e '
const fs = require("fs");
const target = "/app/libexec/stremio/server.js";
if (!fs.existsSync(target)) {
  console.log("MISSING_TARGET");
  process.exit(1);
}
const code = fs.readFileSync(target, "utf8");
const p1 = (code.split("var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5").length - 1);
const p2 = (code.split("MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {").length - 1);
const p3 = (code.split("uploadPipe.push(engine.store.read, index, (function(err, buffer) {").length - 1);

if (p1 === 1 && p2 === 1 && p3 === 1) {
  console.log("MATCH_EXACT_ONE");
  process.exit(0);
} else {
  console.log("MISMATCH: p1=" + p1 + " p2=" + p2 + " p3=" + p3);
  process.exit(2);
}
' 2>/dev/null || echo "CHECK_FAILED")

if [ "${COMPAT_RESULT}" = "MATCH_EXACT_ONE" ]; then
  echo "  [PASS] All 3 structural invariants matched exactly once in active server.js"
  PASSED_CHECKS=$((PASSED_CHECKS+1))
  STATIC_OK=true
else
  echo "  [FAIL] Compatibility fingerprint check failed: ${COMPAT_RESULT}"
  ERRORS=$((ERRORS+1))
  INCOMPATIBLE=true
fi

# ── 4. Runtime Controller & IPC Verification ──────────────────────────────────
echo ""
echo "── 4. Runtime Controller & IPC Verification ──────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS+1))
# Check if any stremio server / node process is listening on 11470
if curl -s --max-time 1 "http://127.0.0.1:11470/heartbeat" &>/dev/null || curl -s --max-time 1 "http://127.0.0.1:11470/zero-upload-controller" &>/dev/null; then
  RUNTIME_RUNNING=true
  PASSED_CHECKS=$((PASSED_CHECKS+1))
  
  # Authoritative controller loopback endpoint check
  TOTAL_CHECKS=$((TOTAL_CHECKS+1))
  CTRL_RESP=$(curl -s --max-time 1 "http://127.0.0.1:11470/zero-upload-controller" 2>/dev/null || curl -s --max-time 1 "http://127.0.0.1:11470/mute-status" 2>/dev/null || echo "")
  
  if [ -n "${CTRL_RESP}" ] && echo "${CTRL_RESP}" | grep -q '"active":true'; then
    CTRL_VER=$(echo "${CTRL_RESP}" | jq -r '.version // "unknown"' 2>/dev/null || echo "1.2.0")
    echo "  [PASS] Stremio server responded to /zero-upload-controller (Controller Version: ${CTRL_VER})"
    PASSED_CHECKS=$((PASSED_CHECKS+1))
    CONTROLLER_RESPONSIVE=true
  else
    echo "  [FAIL] Stremio server is running but zero-upload controller is NOT active (STOCK SERVER DETECTED)"
    ERRORS=$((ERRORS+1))
  fi

  TOTAL_CHECKS=$((TOTAL_CHECKS+1))
  HB=$(curl -s --max-time 1 "http://127.0.0.1:11470/heartbeat" 2>/dev/null || echo "")
  if echo "${HB}" | grep -q '"success":true'; then
    echo "  [PASS] Local IPC heartbeat endpoint healthy (http://127.0.0.1:11470/heartbeat)"
    PASSED_CHECKS=$((PASSED_CHECKS+1))
    HEARTBEAT_OK=true
  else
    echo "  [WARN] Heartbeat endpoint returned unexpected payload: ${HB}"
    WARNS=$((WARNS+1))
  fi
else
  echo "  [INFO] Stremio server is not running right now. (Launch Stremio to verify runtime state)"
fi

# ── 5. Final State Classification ─────────────────────────────────────────────
echo ""
echo "================================================================================"

if [ "$INCOMPATIBLE" = true ]; then
  echo " STATUS: INCOMPATIBLE"
  echo " Verdict: Stremio server code structure has changed. Controller will fail closed."
  echo " Action:  Run './scripts/diagnose.sh' and report compatibility mismatch."
  echo "================================================================================"
  exit 2
elif [ "$NOT_INSTALLED" = true ]; then
  echo " STATUS: NOT INSTALLED"
  echo " Verdict: Stremio Mute is not fully installed on this system."
  echo " Action:  Run './scripts/install.sh' to install."
  echo "================================================================================"
  exit 1
elif [ "$RUNTIME_RUNNING" = true ]; then
  if [ "$CONTROLLER_RESPONSIVE" = true ] && [ "$HEARTBEAT_OK" = true ]; then
    echo " STATUS: RUNTIME VERIFIED (UPLOADS MUTED)"
    echo " Verdict: Stremio server is running with active upload suppression."
    echo "================================================================================"
    exit 0
  else
    echo " STATUS: NOT PROTECTED"
    echo " Verdict: Stremio server is active without controller protection!"
    echo " Action:  Run './scripts/install.sh' to re-apply the Flatpak override."
    echo "================================================================================"
    exit 1
  fi
elif [ "$STATIC_OK" = true ] && [ "$ERRORS" -eq 0 ]; then
  echo " STATUS: CONFIGURED (STATIC VALIDATION PASSED)"
  echo " Verdict: Stremio Mute is correctly installed and ready."
  echo "          Launch Stremio and play a stream to verify runtime protection."
  echo "================================================================================"
  exit 0
else
  echo " STATUS: ERROR"
  echo " Verdict: Incomplete or ambiguous operational state detected (${ERRORS} errors)."
  echo " Action:  Run './scripts/diagnose.sh' for details."
  echo "================================================================================"
  exit 1
fi
