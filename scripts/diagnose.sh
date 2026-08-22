#!/usr/bin/env bash
# scripts/diagnose.sh — Stremio Mute Diagnostic Report Generator
# Generates a sanitized, issue-safe diagnostic summary for troubleshooting.

set -uo pipefail

APP_ID="com.stremio.Stremio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
SOURCE_WRAPPER="${REPO_ROOT}/src/server-wrapper.js"
# shellcheck source=runtime-path.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/runtime-path.sh"
PROJECT_VERSION="$(tr -d '\r\n' < "${REPO_ROOT}/VERSION" 2>/dev/null || printf '%s' unknown)"

sanitize_text() {
  local value="$1"
  local prefix suffix
  while [[ "${value}" == *"${HOME_DIR}"* ]]; do
    prefix="${value%%"${HOME_DIR}"*}"
    suffix="${value#*"${HOME_DIR}"}"
    value="${prefix}\$HOME${suffix}"
  done
  printf '%s' "${value}"
}

sanitize_path() {
  local value="$1"
  if [ "${value#"${HOME_DIR}"}" != "${value}" ]; then
    printf '%s%s' "\$HOME" "${value#"${HOME_DIR}"}"
  else
    printf '%s' "${value}"
  fi
}

sha256_or_absent() {
  local file="$1"
  if [ -f "${file}" ]; then
    sha256sum "${file}" 2>/dev/null | awk '{print $1}' || printf '%s' unavailable
  else
    printf '%s' absent
  fi
}

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
printf '%s\n' "- Repository Version: ${PROJECT_VERSION}"
printf '%s\n' "- Controller Source SHA256: $(sha256_or_absent "${SOURCE_WRAPPER}")"

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
printf '%s\n' '### 3. Canonical Deployment & Legacy Cleanup'
printf '%s\n' "- Canonical SERVER_PATH: $(sanitize_path "${EXPECTED_SERVER_PATH}")"
printf '%s\n' "- Canonical wrapper present: $([ -f "${CANONICAL_WRAPPER}" ] && printf yes || printf no)"
printf '%s\n' "- Canonical wrapper SHA256: $(sha256_or_absent "${CANONICAL_WRAPPER}")"
printf '%s\n' "- Legacy host wrapper path: $(sanitize_path "${LEGACY_WRAPPER}")"
printf '%s\n' "- Legacy host wrapper present: $([ -e "${LEGACY_WRAPPER}" ] && printf yes || printf no)"
printf '%s\n' "- Legacy host wrapper SHA256: $(sha256_or_absent "${LEGACY_WRAPPER}")"
printf '%s\n' '- Repository and installed bytes match: '
if [ -f "${SOURCE_WRAPPER}" ] && [ -f "${CANONICAL_WRAPPER}" ] && cmp -s "${SOURCE_WRAPPER}" "${CANONICAL_WRAPPER}"; then
  printf '%s\n' 'yes'
else
  printf '%s\n' 'no'
fi

printf '%s\n' '- Flatpak User Override (sanitized):'
if command -v flatpak >/dev/null 2>&1; then
  OVERRIDE_TEXT=$(flatpak override --user --show "${APP_ID}" 2>/dev/null || true)
  if printf '%s\n' "${OVERRIDE_TEXT}" | grep -E '(^|[[:space:]])SERVER_PATH=' >/dev/null 2>&1; then
    sanitize_text "${OVERRIDE_TEXT}" | grep -E '(^|[[:space:]])SERVER_PATH='
  else
    printf '%s\n' '  (No user SERVER_PATH override set; checking the app default)'
  fi

  EFFECTIVE_SERVER_PATH=$(flatpak run --command=node "${APP_ID}" -e 'process.stdout.write(process.env.SERVER_PATH || "")' 2>/dev/null || true)
  if [ "${EFFECTIVE_SERVER_PATH}" = "${STOCK_SERVER_PATH}" ]; then
    printf '%s\n' "  Effective SERVER_PATH: ${STOCK_SERVER_PATH} (stock Stremio; Mute disabled)"
  elif [ "${EFFECTIVE_SERVER_PATH}" = "${EXPECTED_SERVER_PATH}" ]; then
    printf '%s\n' "  Effective SERVER_PATH: $(sanitize_path "${EXPECTED_SERVER_PATH}") (Stremio Mute deployment)"
  elif [ -z "${EFFECTIVE_SERVER_PATH}" ]; then
    printf '%s\n' '  Effective SERVER_PATH: MISSING (stock Stremio launcher will fail)'
  else
    printf '%s\n' "  Effective SERVER_PATH: ${EFFECTIVE_SERVER_PATH} (unrecognized)"
  fi
else
  printf '%s\n' '  (Flatpak unavailable)'
fi

printf '%s\n' '- Canonical path runtime visibility:'
if command -v flatpak >/dev/null 2>&1; then
  VISIBILITY_CHECK=$(flatpak run --command=node --env="STREMIO_MUTE_PROBE_PATH=${EXPECTED_SERVER_PATH}" "${APP_ID}" -e '
const fs = require("fs");
try { fs.accessSync(process.env.STREMIO_MUTE_PROBE_PATH, fs.constants.R_OK); console.log("VISIBLE"); }
catch (err) { console.log("NOT_VISIBLE"); process.exit(1); }
' 2>/dev/null || printf '%s\n' 'PROBE_ERROR')
  printf '%s\n' "  ${VISIBILITY_CHECK}"
else
  printf '%s\n' '  UNVERIFIED (Flatpak unavailable)'
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
printf '%s\n' '### 5. Process & Port State'
if command -v flatpak >/dev/null 2>&1; then
  if flatpak ps --columns=application,pid 2>/dev/null | grep -F "${APP_ID}"; then
    printf '%s\n' '- Stremio process: RUNNING'
  else
    printf '%s\n' '- Stremio process: STOPPED'
  fi
else
  printf '%s\n' '- Stremio process: UNVERIFIED (Flatpak unavailable)'
fi
if command -v ss >/dev/null 2>&1; then
  PORT_OWNER=$(ss -ltnp 'sport = :11470' 2>/dev/null || true)
  if [ -n "${PORT_OWNER}" ]; then
    printf '%s\n' '- Port 11470 owner:'
    printf '%s\n' "${PORT_OWNER}"
  else
    printf '%s\n' '- Port 11470 owner: none observed'
  fi
else
  printf '%s\n' '- Port 11470 owner: unavailable (ss not installed)'
fi

printf '%s\n' ''
printf '%s\n' '### 6. Runtime Telemetry'
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
printf '%s\n' " Report complete. Paths are normalized to \$HOME and no credentials are included."
printf '%s\n' '================================================================================'
