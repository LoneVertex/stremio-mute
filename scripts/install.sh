#!/usr/bin/env bash
# scripts/install.sh — Stremio Mute Installer
# Preflight -> validate -> stop -> stage canonical Flatpak path -> verify visibility -> verify.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
APP_ID="com.stremio.Stremio"
WRAPPER_SRC="${REPO_ROOT}/src/server-wrapper.js"
# shellcheck source=runtime-path.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/runtime-path.sh"

printf '%s\n' '================================================================================'
printf '%s\n' ' STREMIO MUTE — INSTALLER'
printf '%s\n' ' Tagline: Mute BitTorrent peer uploads. Keep streaming.'
printf '%s\n' '================================================================================'

printf '%s\n' '[1/9] Detecting system prerequisites...'
if ! command -v flatpak >/dev/null 2>&1; then
  printf '%s\n' "  [ERROR] 'flatpak' command not found. Flatpak is required." >&2
  exit 1
fi
printf '%s\n' '  [PASS] Flatpak CLI detected.'

printf '%s\n' "[2/9] Inspecting Flatpak installation for ${APP_ID}..."
if ! flatpak info "${APP_ID}" >/dev/null 2>&1; then
  printf '%s\n' "  [ERROR] ${APP_ID} is not installed via Flatpak." >&2
  printf '%s\n' "  Install it first with: flatpak install flathub ${APP_ID}" >&2
  exit 1
fi
printf '%s\n' "  [PASS] ${APP_ID} Flatpak installation confirmed."

printf '%s\n' '[3/9] Running pre-flight compatibility check against Stremio engine...'
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

printf '%s\n' '[4/9] Validating wrapper source and syntax...'
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
  printf '%s\n' '  [INFO] Host Node.js is unavailable; wrapper syntax is covered by the project test suite.'
fi

printf '%s\n' "[5/9] Stopping any running ${APP_ID} process before deployment..."
if flatpak ps --columns=application 2>/dev/null | grep -Fx "${APP_ID}" >/dev/null; then
  flatpak kill "${APP_ID}"
  printf '%s\n' '  [PASS] Existing Stremio process stopped so the next launch loads fresh wrapper bytes.'
else
  printf '%s\n' '  [INFO] No running Stremio process detected.'
fi

printf '%s\n' "[6/9] Staging wrapper at canonical Flatpak app-owned path ${CANONICAL_WRAPPER}..."
mkdir -p "${CANONICAL_WRAPPER_DIR}"
install -m 0644 "${WRAPPER_SRC}" "${CANONICAL_WRAPPER}"
if [ "$(stat -c '%a' "${CANONICAL_WRAPPER}" 2>/dev/null || stat -f '%Lp' "${CANONICAL_WRAPPER}")" != '644' ]; then
  printf '%s\n' "  [ERROR] Staged wrapper permissions are not 0644: ${CANONICAL_WRAPPER}" >&2
  exit 1
fi
if ! cmp -s "${WRAPPER_SRC}" "${CANONICAL_WRAPPER}"; then
  printf '%s\n' '  [ERROR] Staged wrapper does not match the repository source.' >&2
  exit 1
fi
printf '%s\n' '  [PASS] Wrapper staged with mode 0644 and matching source bytes.'

printf '%s\n' '[7/9] Removing the project-managed legacy host wrapper...'
if [ -e "${LEGACY_WRAPPER}" ] || [ -L "${LEGACY_WRAPPER}" ]; then
  rm -f "${LEGACY_WRAPPER}"
  printf '%s\n' "  [PASS] Removed legacy host wrapper: ${LEGACY_WRAPPER}"
else
  printf '%s\n' '  [INFO] No legacy host wrapper found.'
fi
if [ -e "${LEGACY_WRAPPER}" ] || [ -L "${LEGACY_WRAPPER}" ]; then
  printf '%s\n' "  [ERROR] Legacy wrapper remains selectable: ${LEGACY_WRAPPER}" >&2
  exit 1
fi

printf '%s\n' "[8/9] Applying and validating canonical absolute SERVER_PATH..."
flatpak override --user --env="SERVER_PATH=${EXPECTED_SERVER_PATH}" "${APP_ID}"
OVERRIDE_SHOW=$(flatpak override --user --show "${APP_ID}" 2>/dev/null || true)
OVERRIDE_LINE=$(printf '%s\n' "${OVERRIDE_SHOW}" | grep -E '(^|[[:space:]])SERVER_PATH=' | tail -n 1 || true)
ACTUAL_SERVER_PATH="${OVERRIDE_LINE#*SERVER_PATH=}"
if [ "${ACTUAL_SERVER_PATH}" != "${EXPECTED_SERVER_PATH}" ] || [[ "${ACTUAL_SERVER_PATH}" != /* ]]; then
  printf '%s\n' "  [ERROR] Persisted SERVER_PATH is not the canonical absolute path: ${ACTUAL_SERVER_PATH:-<missing>}" >&2
  exit 1
fi
printf '%s\n' "  [PASS] Persisted SERVER_PATH=${EXPECTED_SERVER_PATH}"

printf '%s\n' '[9/9] Proving canonical path visibility inside the Flatpak sandbox...'
VISIBILITY_CHECK=$(flatpak run --command=node --env="STREMIO_MUTE_PROBE_PATH=${EXPECTED_SERVER_PATH}" "${APP_ID}" -e '
const fs = require("fs");
const p = process.env.STREMIO_MUTE_PROBE_PATH;
try {
  fs.accessSync(p, fs.constants.R_OK);
  console.log("VISIBLE");
} catch (err) {
  console.log("NOT_VISIBLE");
  process.exit(1);
}
' 2>/dev/null || printf '%s\n' 'PROBE_ERROR')
if [ "${VISIBILITY_CHECK}" != 'VISIBLE' ]; then
  printf '%s\n' "  [ERROR] Canonical wrapper is not readable inside the Flatpak sandbox: ${EXPECTED_SERVER_PATH} (${VISIBILITY_CHECK})" >&2
  exit 1
fi
printf '%s\n' '  [PASS] Canonical wrapper is readable inside the Flatpak sandbox.'

printf '%s\n' 'Running operational verification...'
bash "${SCRIPT_DIR}/verify.sh"

printf '%s\n' '================================================================================'
printf '%s\n' ' INSTALLATION SUCCESSFUL'
printf '%s\n' '================================================================================'
printf '%s\n' " Canonical wrapper: ${CANONICAL_WRAPPER}"
printf '%s\n' " Stored override: SERVER_PATH=${EXPECTED_SERVER_PATH}"
printf '%s\n' ' Status: Stremio Mute is ready for runtime verification when Stremio is launched.'
printf '%s\n' " Verify: ${SCRIPT_DIR}/verify.sh"
printf '%s\n' '================================================================================'
