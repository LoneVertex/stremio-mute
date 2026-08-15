#!/usr/bin/env bash
# scripts/verify.sh — Stremio Mute Operational Health Check
# States: NOT INSTALLED | CONFIGURED | RUNTIME VERIFIED | NOT PROTECTED | INCOMPATIBLE | ERROR

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
APP_ID="com.stremio.Stremio"
SOURCE_WRAPPER="${REPO_ROOT}/src/server-wrapper.js"
# shellcheck source=runtime-path.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/runtime-path.sh"
PROJECT_VERSION="$(tr -d '\r\n' < "${REPO_ROOT}/VERSION" 2>/dev/null || printf '%s' unknown)"
EXPECTED_CONTROLLER_SHA256=""
ERRORS=0
STATIC_OK=false
RUNTIME_RUNNING=false
CONTROLLER_RESPONSIVE=false
METADATA_OK=false
HEARTBEAT_OK=false
INVARIANTS_OK=false
INCOMPATIBLE=false
NOT_INSTALLED=false
LEGACY_PRESENT=false
CANONICAL_VISIBLE=false

json_string_field() {
  local json="$1"
  local field="$2"
  printf '%s' "${json}" | tr -d '\n' | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

json_bool_field() {
  local json="$1"
  local field="$2"
  printf '%s' "${json}" | tr -d '\n' | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p"
}

json_number_field() {
  local json="$1"
  local field="$2"
  printf '%s' "${json}" | tr -d '\n' | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p"
}

printf '%s\n' '================================================================================'
printf '%s\n' ' STREMIO MUTE — OPERATIONAL HEALTH CHECK'
printf '%s\n' ' Tagline: Mute BitTorrent peer uploads. Keep streaming.'
printf '%s\n' '================================================================================'

printf '%s\n' ''
printf '%s\n' '── 1. Canonical Controller File & Integrity ─────────────────────────────────'
printf '%s\n' "  [INFO] Canonical wrapper path: ${CANONICAL_WRAPPER}"
printf '%s\n' "  [INFO] Legacy host wrapper path: ${LEGACY_WRAPPER}"
if [ ! -e "${CANONICAL_WRAPPER}" ]; then
  printf '%s\n' "  [FAIL] Canonical controller file missing at: ${CANONICAL_WRAPPER}"
  NOT_INSTALLED=true
elif [ -L "${CANONICAL_WRAPPER}" ]; then
  printf '%s\n' "  [FAIL] Canonical controller file must not be a symlink: ${CANONICAL_WRAPPER}"
  ERRORS=$((ERRORS+1))
else
  printf '%s\n' '  [PASS] Canonical controller file exists.'
  PERMS=$(stat -c '%a' "${CANONICAL_WRAPPER}" 2>/dev/null || stat -f '%Lp' "${CANONICAL_WRAPPER}" 2>/dev/null || printf '%s' unknown)
  if [ "${PERMS}" = '644' ] || [ "${PERMS}" = '755' ]; then
    printf '%s\n' "  [PASS] Controller permissions are safe (${PERMS})."
  else
    printf '%s\n' "  [FAIL] Unsafe controller permissions: ${PERMS} (expected 644)."
    ERRORS=$((ERRORS+1))
  fi
  if command -v node >/dev/null 2>&1; then
    if node -c "${CANONICAL_WRAPPER}" >/dev/null 2>&1; then
      printf '%s\n' '  [PASS] Controller JavaScript syntax is valid.'
    else
      printf '%s\n' '  [FAIL] Controller JavaScript syntax is invalid.'
      ERRORS=$((ERRORS+1))
    fi
  else
    printf '%s\n' '  [INFO] Host Node.js unavailable; syntax check deferred to installation/test suite.'
  fi
  if [ ! -f "${SOURCE_WRAPPER}" ]; then
    printf '%s\n' "  [FAIL] Repository source wrapper is missing: ${SOURCE_WRAPPER}"
    ERRORS=$((ERRORS+1))
  elif cmp -s "${SOURCE_WRAPPER}" "${CANONICAL_WRAPPER}"; then
    EXPECTED_CONTROLLER_SHA256=$(sha256sum "${CANONICAL_WRAPPER}" 2>/dev/null | awk '{print $1}' || true)
    printf '%s\n' '  [PASS] Canonical wrapper bytes match the repository source.'
    printf '%s\n' "  [PASS] Canonical wrapper SHA256: ${EXPECTED_CONTROLLER_SHA256}"
  else
    printf '%s\n' '  [FAIL] Canonical wrapper differs from the repository source.'
    ERRORS=$((ERRORS+1))
  fi
fi
if [ -e "${LEGACY_WRAPPER}" ] || [ -L "${LEGACY_WRAPPER}" ]; then
  LEGACY_PRESENT=true
  printf '%s\n' "  [FAIL] Project-managed legacy wrapper remains at: ${LEGACY_WRAPPER}"
else
  printf '%s\n' '  [PASS] Project-managed legacy host wrapper is absent.'
fi

printf '%s\n' ''
printf '%s\n' '── 2. Flatpak Installation, Override & Visibility ───────────────────────────'
if ! command -v flatpak >/dev/null 2>&1; then
  printf '%s\n' "  [ERROR] 'flatpak' command not found; installation state cannot be determined."
  ERRORS=$((ERRORS+1))
else
  if flatpak info "${APP_ID}" >/dev/null 2>&1; then
    printf '%s\n' "  [PASS] ${APP_ID} is installed via Flatpak."
  else
    printf '%s\n' "  [FAIL] ${APP_ID} is not installed via Flatpak."
    NOT_INSTALLED=true
  fi

  OVERRIDE_SHOW=$(flatpak override --user --show "${APP_ID}" 2>/dev/null || true)
  OVERRIDE_SOURCE="flatpak override --user --show"
  if [ -z "${OVERRIDE_SHOW}" ] && [ -f "${OVERRIDE_FILE}" ]; then
    OVERRIDE_SHOW=$(cat "${OVERRIDE_FILE}")
    OVERRIDE_SOURCE="override file fallback"
  fi
  ACTUAL_SERVER_PATH=$(printf '%s\n' "${OVERRIDE_SHOW}" | grep -oE 'SERVER_PATH=[^[:space:]]+' | tail -n 1 | cut -d= -f2- || true)

  if [ "${ACTUAL_SERVER_PATH}" = "${EXPECTED_SERVER_PATH}" ] && [[ "${ACTUAL_SERVER_PATH}" = /* ]]; then
    printf '%s\n' "  [PASS] ${OVERRIDE_SOURCE} stores canonical absolute SERVER_PATH=${ACTUAL_SERVER_PATH}"
  elif [ -z "${ACTUAL_SERVER_PATH}" ]; then
    printf '%s\n' '  [FAIL] SERVER_PATH override is missing.'
    NOT_INSTALLED=true
  elif case "${ACTUAL_SERVER_PATH}" in \~/*) true ;; *) false ;; esac; then
    printf '%s\n' "  [FAIL] SERVER_PATH incorrectly contains a literal tilde: ${ACTUAL_SERVER_PATH}"
    NOT_INSTALLED=true
  else
    printf '%s\n' "  [FAIL] SERVER_PATH is incorrect: ${ACTUAL_SERVER_PATH} (expected ${EXPECTED_SERVER_PATH})"
    NOT_INSTALLED=true
  fi

  if [ "${NOT_INSTALLED}" = false ]; then
    VISIBILITY_CHECK=$(flatpak run --command=node --env="STREMIO_MUTE_PROBE_PATH=${EXPECTED_SERVER_PATH}" "${APP_ID}" -e '
const fs = require("fs");
try {
  fs.accessSync(process.env.STREMIO_MUTE_PROBE_PATH, fs.constants.R_OK);
  console.log("VISIBLE");
} catch (err) {
  console.log("NOT_VISIBLE");
  process.exit(1);
}
' 2>/dev/null || printf '%s\n' 'PROBE_ERROR')
    if [ "${VISIBILITY_CHECK}" = 'VISIBLE' ]; then
      CANONICAL_VISIBLE=true
      printf '%s\n' '  [PASS] Canonical wrapper is readable inside the Flatpak sandbox.'
    else
      printf '%s\n' "  [FAIL] Canonical wrapper is not readable inside the Flatpak sandbox (${VISIBILITY_CHECK})."
      NOT_INSTALLED=true
    fi
  fi
fi

printf '%s\n' ''
printf '%s\n' '── 3. Structural Compatibility Fingerprints ─────────────────────────────────'
if [ "${NOT_INSTALLED}" = true ] || ! command -v flatpak >/dev/null 2>&1; then
  printf '%s\n' '  [INFO] Compatibility check deferred because canonical Flatpak installation is unavailable.'
else
  COMPAT_RESULT=$(flatpak run --command=node "${APP_ID}" -e '
const fs = require("fs");
const target = "/app/libexec/stremio/server.js";
if (!fs.existsSync(target)) {
  console.log("MISSING_TARGET");
  process.exit(1);
}
const code = fs.readFileSync(target, "utf8");
const p1 = code.split("var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5").length - 1;
const p2Actual = code.split("MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {").length - 1;
const p3 = code.split("uploadPipe.push(engine.store.read, index, (function(err, buffer) {").length - 1;
if (p1 === 1 && p2Actual === 1 && p3 === 1) {
  console.log("MATCH_EXACT_ONE");
  process.exit(0);
}
console.log("MISMATCH: p1=" + p1 + " p2=" + p2Actual + " p3=" + p3);
process.exit(2);
' 2>/dev/null || printf '%s' 'CHECK_FAILED')
  case "${COMPAT_RESULT}" in
    MATCH_EXACT_ONE)
      printf '%s\n' '  [PASS] All three structural fingerprints matched exactly once.'
      ;;
    MISSING_TARGET|MISMATCH:*)
      printf '%s\n' "  [FAIL] Active server.js is incompatible: ${COMPAT_RESULT}"
      INCOMPATIBLE=true
      ;;
    *)
      printf '%s\n' "  [ERROR] Compatibility check could not be completed: ${COMPAT_RESULT}"
      ERRORS=$((ERRORS+1))
      ;;
  esac
fi

if [ "${NOT_INSTALLED}" = false ] && [ "${ERRORS}" -eq 0 ] && [ "${INCOMPATIBLE}" = false ] && [ "${LEGACY_PRESENT}" = false ] && [ "${CANONICAL_VISIBLE}" = true ]; then
  STATIC_OK=true
fi

printf '%s\n' ''
printf '%s\n' '── 4. Runtime Controller, Identity & IPC Verification ──────────────────────'
if ! command -v curl >/dev/null 2>&1; then
  printf '%s\n' "  [ERROR] 'curl' command not found; runtime state cannot be determined."
  ERRORS=$((ERRORS+1))
else
  CONTROLLER_RESP=$(curl -fsS --max-time 1 'http://127.0.0.1:11470/zero-upload-controller' 2>/dev/null || true)
  HEARTBEAT_RESP=$(curl -fsS --max-time 1 'http://127.0.0.1:11470/heartbeat' 2>/dev/null || true)
  if [ -n "${CONTROLLER_RESP}" ] || [ -n "${HEARTBEAT_RESP}" ]; then
    RUNTIME_RUNNING=true
    printf '%s\n' '  [PASS] A Stremio server endpoint responded on loopback port 11470.'
    if [ -n "${CONTROLLER_RESP}" ] && [ "$(json_string_field "${CONTROLLER_RESP}" project)" = 'stremio-mute' ] && [ "$(json_bool_field "${CONTROLLER_RESP}" active)" = 'true' ]; then
      CONTROLLER_RESPONSIVE=true
      printf '%s\n' '  [PASS] Active stremio-mute controller endpoint confirmed.'
      RUNTIME_VERSION="$(json_string_field "${CONTROLLER_RESP}" version)"
      RUNTIME_SOURCE_SHA256="$(json_string_field "${CONTROLLER_RESP}" sourceSha256)"
      if [ "${RUNTIME_VERSION}" = "${PROJECT_VERSION}" ] && [ -n "${EXPECTED_CONTROLLER_SHA256}" ] && [ "${RUNTIME_SOURCE_SHA256}" = "${EXPECTED_CONTROLLER_SHA256}" ]; then
        METADATA_OK=true
        printf '%s\n' "  [PASS] Runtime metadata matches VERSION=${PROJECT_VERSION} and canonical wrapper SHA256=${EXPECTED_CONTROLLER_SHA256}."
      else
        printf '%s\n' "  [FAIL] Runtime metadata is stale or from another wrapper (runtime version=${RUNTIME_VERSION:-<missing>}, expected=${PROJECT_VERSION}, runtime SHA256=${RUNTIME_SOURCE_SHA256:-<missing>}, expected=${EXPECTED_CONTROLLER_SHA256:-<missing>})."
      fi
      RUNTIME_UPLOADS="$(json_number_field "${CONTROLLER_RESP}" uploads)"
      RUNTIME_RECHOKE="$(json_number_field "${CONTROLLER_RESP}" rechokeSlots)"
      RUNTIME_WIRE_BLOCKED="$(json_bool_field "${CONTROLLER_RESP}" wireRequestBlocked)"
      RUNTIME_MUTED="$(json_bool_field "${CONTROLLER_RESP}" muted)"
      if [ "${RUNTIME_UPLOADS}" = '0' ] && [ "${RUNTIME_RECHOKE}" = '0' ] && [ "${RUNTIME_WIRE_BLOCKED}" = 'true' ] && [ "${RUNTIME_MUTED}" = 'true' ]; then
        INVARIANTS_OK=true
        printf '%s\n' '  [PASS] Upload-suppression invariants are active (uploads=0, rechokeSlots=0, wireRequestBlocked=true).'
      else
        printf '%s\n' "  [FAIL] Upload-suppression invariants are incomplete (uploads=${RUNTIME_UPLOADS:-<missing>}, rechokeSlots=${RUNTIME_RECHOKE:-<missing>}, wireRequestBlocked=${RUNTIME_WIRE_BLOCKED:-<missing>}, muted=${RUNTIME_MUTED:-<missing>})."
      fi
    else
      printf '%s\n' '  [FAIL] Runtime responded without the expected active stremio-mute controller evidence.'
    fi
    if [ "$(json_bool_field "${HEARTBEAT_RESP}" success)" = 'true' ]; then
      HEARTBEAT_OK=true
      printf '%s\n' '  [PASS] Loopback heartbeat is healthy.'
    else
      printf '%s\n' '  [FAIL] Loopback heartbeat is missing or unhealthy.'
    fi
  else
    printf '%s\n' '  [INFO] Stremio is not running; runtime protection is not claimed.'
  fi
fi

printf '%s\n' ''
printf '%s\n' '================================================================================'
if [ "${INCOMPATIBLE}" = true ]; then
  printf '%s\n' ' STATUS: INCOMPATIBLE'
  printf '%s\n' ' Verdict: Stremio server structure changed; the controller remains fail-closed.'
  exit 2
elif [ "${RUNTIME_RUNNING}" = true ]; then
  if [ "${CONTROLLER_RESPONSIVE}" = true ] && [ "${METADATA_OK}" = true ] && [ "${INVARIANTS_OK}" = true ] && [ "${HEARTBEAT_OK}" = true ] && [ "${STATIC_OK}" = true ]; then
    printf '%s\n' ' STATUS: RUNTIME VERIFIED'
    printf '%s\n' ' Verdict: The active runtime controller, canonical deployment identity, invariants, and heartbeat prove protected execution.'
    exit 0
  fi
  printf '%s\n' ' STATUS: NOT PROTECTED'
  printf '%s\n' ' Verdict: Stremio is running without complete canonical path, controller, identity, invariant, and heartbeat evidence.'
  exit 1
elif [ "${NOT_INSTALLED}" = true ]; then
  printf '%s\n' ' STATUS: NOT INSTALLED'
  printf '%s\n' ' Verdict: Required canonical Flatpak deployment or exact absolute-path configuration is missing.'
  exit 1
elif [ "${ERRORS}" -gt 0 ] || [ "${LEGACY_PRESENT}" = true ] || [ "${STATIC_OK}" = false ]; then
  printf '%s\n' ' STATUS: ERROR'
  printf '%s\n' ' Verdict: The verifier could not establish a clean canonical installation state.'
  exit 1
else
  printf '%s\n' ' STATUS: CONFIGURED'
  printf '%s\n' ' Verdict: Static canonical installation is valid; launch Stremio for runtime verification.'
  exit 0
fi
