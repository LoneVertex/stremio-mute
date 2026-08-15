#!/usr/bin/env bash
# scripts/install.sh — Stremio Mute Installer
# Preflight -> validate -> stage -> apply absolute SERVER_PATH -> verify.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
APP_ID="com.stremio.Stremio"
WRAPPER_SRC="${REPO_ROOT}/src/server-wrapper.js"
HOME_DIR="$(cd "${HOME}" && pwd -P)"
WRAPPER_DIR="${HOME_DIR}/.stremio-server"
TARGET_WRAPPER="${WRAPPER_DIR}/server-wrapper.js"
EXPECTED_SERVER_PATH="${TARGET_WRAPPER}"

printf '%s\n' '================================================================================'
printf '%s\n' ' STREMIO MUTE — INSTALLER'
printf '%s\n' ' Tagline: Mute BitTorrent peer uploads. Keep streaming.'
printf '%s\n' '================================================================================'

printf '%s\n' '[1/8] Detecting system prerequisites...'
if ! command -v flatpak >/dev/null 2>&1; then
  printf '%s\n' "  [ERROR] 'flatpak' command not found. Flatpak is required." >&2
  exit 1
fi
printf '%s\n' '  [PASS] Flatpak CLI detected.'

printf '%s\n' "[2/8] Inspecting Flatpak installation for ${APP_ID}..."
if ! flatpak info "${APP_ID}" >/dev/null 2>&1; then
  printf '%s\n' "  [ERROR] ${APP_ID} is not installed via Flatpak." >&2
  printf '%s\n' "  Install it first with: flatpak install flathub ${APP_ID}" >&2
  exit 1
fi
printf '%s\n' "  [PASS] ${APP_ID} Flatpak installation confirmed."

printf '%s\n' '[3/8] Running pre-flight compatibility check against Stremio engine...'
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
}
console.log("COMPAT_FAIL: p1=" + p1 + " p2=" + p2 + " p3=" + p3);
process.exit(2);
' 2>/dev/null || printf '%s\n' 'COMPAT_ERR')

if [ "${COMPAT_CHECK}" != 'COMPAT_OK' ]; then
  printf '%s\n' "  [FATAL] Pre-flight compatibility validation failed: ${COMPAT_CHECK}" >&2
  printf '%s\n' '  Installation aborted before staging or changing the Flatpak override.' >&2
  exit 2
fi
printf '%s\n' '  [PASS] Stremio server.js structural fingerprints verified (exact-one match).'

printf '%s\n' '[4/8] Validating wrapper source and syntax...'
if [ ! -f "${WRAPPER_SRC}" ] || [ -L "${WRAPPER_SRC}" ]; then
  printf '%s\n' "  [ERROR] Source wrapper is missing or unexpectedly symlinked: ${WRAPPER_SRC}" >&2
  exit 1
fi
if command -v node >/dev/null 2>&1; then
  if ! node -c "${WRAPPER_SRC}" >/dev/null 2>&1; then
    printf '%s\n' "  [ERROR] Wrapper JavaScript syntax is invalid: ${WRAPPER_SRC}" >&2
    exit 1
  fi
  printf '%s\n' '  [PASS] Wrapper source exists and has valid JavaScript syntax.'
else
  printf '%s\n' '  [INFO] Host Node.js is unavailable; wrapper bytes and syntax are covered by the project test suite.'
fi

printf '%s\n' "[5/8] Staging wrapper at ${TARGET_WRAPPER}..."
mkdir -p "${WRAPPER_DIR}"
install -m 0644 "${WRAPPER_SRC}" "${TARGET_WRAPPER}"
if [ "$(stat -c '%a' "${TARGET_WRAPPER}" 2>/dev/null || stat -f '%Lp' "${TARGET_WRAPPER}")" != '644' ]; then
  printf '%s\n' "  [ERROR] Staged wrapper permissions are not 0644: ${TARGET_WRAPPER}" >&2
  exit 1
fi
if ! cmp -s "${WRAPPER_SRC}" "${TARGET_WRAPPER}"; then
  printf '%s\n' '  [ERROR] Staged wrapper does not match the repository source.' >&2
  exit 1
fi
printf '%s\n' '  [PASS] Wrapper staged with mode 0644 and matching source bytes.'

printf '%s\n' "[6/8] Applying absolute Flatpak user environment override..."
flatpak override --user --env="SERVER_PATH=${EXPECTED_SERVER_PATH}" "${APP_ID}"
printf '%s\n' "  [PASS] Requested SERVER_PATH=${EXPECTED_SERVER_PATH}"

printf '%s\n' '[7/8] Verifying the persisted Flatpak override...'
OVERRIDE_SHOW=$(flatpak override --user --show "${APP_ID}" 2>/dev/null || true)
OVERRIDE_LINE=$(printf '%s\n' "${OVERRIDE_SHOW}" | grep -E '(^|[[:space:]])SERVER_PATH=' | tail -n 1 || true)
ACTUAL_SERVER_PATH="${OVERRIDE_LINE#*SERVER_PATH=}"
if [ "${ACTUAL_SERVER_PATH}" != "${EXPECTED_SERVER_PATH}" ]; then
  printf '%s\n' "  [ERROR] Persisted SERVER_PATH is not the expected absolute path: ${ACTUAL_SERVER_PATH:-<missing>}" >&2
  exit 1
fi
printf '%s\n' "  [PASS] Persisted SERVER_PATH exactly matches ${EXPECTED_SERVER_PATH}"

printf '%s\n' '[8/8] Running operational verification...'
bash "${SCRIPT_DIR}/verify.sh"

printf '%s\n' '================================================================================'
printf '%s\n' ' INSTALLATION SUCCESSFUL'
printf '%s\n' '================================================================================'
printf '%s\n' " Staged wrapper: ${TARGET_WRAPPER}"
printf '%s\n' " Stored override: SERVER_PATH=${EXPECTED_SERVER_PATH}"
printf '%s\n' ' Status: Stremio Mute is ready for runtime verification when Stremio is launched.'
printf '%s\n' " Verify: ${SCRIPT_DIR}/verify.sh"
printf '%s\n' '================================================================================'
