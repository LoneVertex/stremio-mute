#!/usr/bin/env bash
# tests/static/test_absolute_path.sh — Canonical Flatpak-visible SERVER_PATH tests
# Reproduces the old host-only path failure through an isolated Flatpak mock.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
INSTALLER="${REPO_ROOT}/scripts/install.sh"
VERIFIER="${REPO_ROOT}/scripts/verify.sh"
ROLLBACK="${REPO_ROOT}/scripts/rollback.sh"
DIAGNOSE="${REPO_ROOT}/scripts/diagnose.sh"
TMP_DIR=$(mktemp -d)
MOCK_BIN="${TMP_DIR}/bin"
MOCK_HOME_A="${TMP_DIR}/home-a"
MOCK_HOME_B="${TMP_DIR}/home-b"
mkdir -p "${MOCK_BIN}" "${MOCK_HOME_A}" "${MOCK_HOME_B}"
trap 'rm -rf "${TMP_DIR}"' EXIT

cat > "${MOCK_BIN}/flatpak" <<'MOCK_FLATPAK'
#!/usr/bin/env bash
set -u
STATE_FILE="${MOCK_STATE:?}"
APP_DEFAULT_SERVER_PATH='/app/libexec/stremio/server.js'
mkdir -p "$(dirname "${STATE_FILE}")"

state_value() {
  local key="$1"
  if [ -f "${STATE_FILE}" ]; then
    sed -n "s/^${key}=//p" "${STATE_FILE}" | tail -n 1
  fi
}

effective_server_path() {
  if [ "$(state_value UNSET_SERVER_PATH)" = '1' ]; then
    return 0
  fi
  if [ -n "$(state_value SERVER_PATH)" ]; then
    state_value SERVER_PATH
  else
    printf '%s\n' "${APP_DEFAULT_SERVER_PATH}"
  fi
}

case "${1:-}" in
  info)
    exit 0
    ;;
  ps)
    exit 0
    ;;
  kill)
    exit 0
    ;;
  run)
    if printf '%s\n' "$*" | grep -Fq -- 'STREMIO_MUTE_PROBE_PATH='; then
      if [ "${MOCK_FAIL_STOCK_TARGET:-0}" = '1' ] && printf '%s\n' "$*" | grep -Fq -- 'STREMIO_MUTE_PROBE_PATH=/app/libexec/stremio/server.js'; then
        exit 1
      fi
      printf '%s\n' 'VISIBLE'
    elif printf '%s\n' "$*" | grep -Fq 'MATCH_EXACT_ONE'; then
      printf '%s\n' 'MATCH_EXACT_ONE'
    elif printf '%s\n' "$*" | grep -Fq 'COMPAT_OK'; then
      printf '%s\n' 'COMPAT_OK'
    else
      if [ "${MOCK_EFFECTIVE_MISMATCH:-0}" = '1' ] && printf '%s\n' "$*" | grep -Fq 'process.env.SERVER_PATH'; then
        printf '%s\n' '/wrong/effective/server.js'
        exit 0
      fi
      SERVER_PATH_VALUE="$(effective_server_path)"
      if [ -n "${SERVER_PATH_VALUE}" ]; then
        printf '%s\n' "${SERVER_PATH_VALUE}"
      fi
      [ -n "${SERVER_PATH_VALUE}" ]
    fi
    exit $?
    ;;
  override)
    for arg in "$@"; do
      case "${arg}" in
        --env=SERVER_PATH=*)
          if [ "${MOCK_FAIL_STOCK_RESTORE:-0}" = '1' ] && [ "${arg#--env=SERVER_PATH=}" = "${APP_DEFAULT_SERVER_PATH}" ]; then
            exit 1
          fi
          printf '%s\n' "${arg#--env=}" > "${STATE_FILE}"
          exit 0
          ;;
        --unset-env=SERVER_PATH)
          printf '%s\n' 'UNSET_SERVER_PATH=1' > "${STATE_FILE}"
          exit 0
          ;;
      esac
    done
    if printf '%s\n' "$*" | grep -Fq -- '--show'; then
      if [ -f "${STATE_FILE}" ]; then
        cat "${STATE_FILE}"
      fi
      exit 0
    fi
    exit 0
    ;;
esac
exit 0
MOCK_FLATPAK
chmod +x "${MOCK_BIN}/flatpak"

pass_count=0
fail_count=0
pass_test() {
  pass_count=$((pass_count+1))
  printf '%s\n' "  [PASS] $1"
}
fail_test() {
  fail_count=$((fail_count+1))
  printf '%s\n' "  [FAIL] $1" >&2
}
run_with_env() {
  local home_dir="$1"
  local state_file="$2"
  shift 2
  HOME="${home_dir}" MOCK_STATE="${state_file}" PATH="${MOCK_BIN}:${PATH}" \
    MOCK_FAIL_STOCK_TARGET="${MOCK_FAIL_STOCK_TARGET:-0}" \
    MOCK_FAIL_STOCK_RESTORE="${MOCK_FAIL_STOCK_RESTORE:-0}" \
    MOCK_EFFECTIVE_MISMATCH="${MOCK_EFFECTIVE_MISMATCH:-0}" "$@"
}

printf '%s\n' '================================================================================'
printf '%s\n' ' RUNNING CANONICAL FLATPAK PATH REGRESSION TESTS'
printf '%s\n' '================================================================================'

if grep -Fq -- '--unset-env=SERVER_PATH' "${ROLLBACK}"; then
  fail_test 'rollback does not unset the required SERVER_PATH environment variable'
else
  pass_test 'rollback does not unset the required SERVER_PATH environment variable'
fi
if grep -Fq -- 'STOCK_SERVER_PATH' "${ROLLBACK}"; then
  pass_test 'rollback restores SERVER_PATH through the shared stock-path constant'
else
  fail_test 'rollback restores SERVER_PATH through the shared stock-path constant'
fi

STATE_A="${TMP_DIR}/state-a"
LOG_A="${TMP_DIR}/install-a.log"
CANONICAL_A="${MOCK_HOME_A}/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js"
LEGACY_A="${MOCK_HOME_A}/.stremio-server/server-wrapper.js"
if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${INSTALLER}" >"${LOG_A}" 2>&1; then
  if grep -Fxq "SERVER_PATH=${CANONICAL_A}" "${STATE_A}" && [ -f "${CANONICAL_A}" ] && [ ! -e "${LEGACY_A}" ]; then
    pass_test 'install.sh selects and persists the canonical Flatpak-visible path'
  else
    fail_test 'install.sh selects and persists the canonical Flatpak-visible path'
  fi
  if ! grep -Fq 'SERVER_PATH=~/.stremio-server/server-wrapper.js' "${LOG_A}"; then
    pass_test 'installer output contains no obsolete literal-tilde path'
  else
    fail_test 'installer output contains no obsolete literal-tilde path'
  fi
else
  cat "${LOG_A}" >&2
  fail_test 'install.sh succeeds in the isolated Flatpak mock'
fi

if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${VERIFIER}" >"${TMP_DIR}/verify-correct.out" 2>&1; then
  if grep -Fq 'STATUS: CONFIGURED' "${TMP_DIR}/verify-correct.out"; then
    pass_test 'verify.sh accepts the canonical absolute path and visibility proof'
  else
    fail_test 'verify.sh accepts the canonical absolute path and visibility proof'
  fi
else
  cat "${TMP_DIR}/verify-correct.out" >&2
  fail_test 'verify.sh returns success for the canonical path'
fi

printf '%s\n' 'SERVER_PATH=~/.stremio-server/server-wrapper.js' > "${STATE_A}"
if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${VERIFIER}" >"${TMP_DIR}/verify-tilde.out" 2>&1; then
  fail_test 'verify.sh rejects the literal tilde path'
else
  if grep -Fq 'STATUS: NOT INSTALLED' "${TMP_DIR}/verify-tilde.out"; then
    pass_test 'verify.sh rejects the literal tilde path'
  else
    fail_test 'verify.sh rejects the literal tilde path with a clear state'
  fi
fi

printf '%s\n' "SERVER_PATH=${TMP_DIR}/wrong/server-wrapper.js" > "${STATE_A}"
if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${VERIFIER}" >"${TMP_DIR}/verify-wrong.out" 2>&1; then
  fail_test 'verify.sh rejects an incorrect absolute path'
else
  if grep -Fq 'STATUS: NOT INSTALLED' "${TMP_DIR}/verify-wrong.out"; then
    pass_test 'verify.sh rejects an incorrect absolute path'
  else
    fail_test 'verify.sh rejects an incorrect absolute path with a clear state'
  fi
fi

printf '%s\n' "SERVER_PATH=${LEGACY_A}" > "${STATE_A}"
if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${VERIFIER}" >"${TMP_DIR}/verify-host-only.out" 2>&1; then
  fail_test 'verify.sh rejects the old host-only wrapper path'
else
  if grep -Fq 'STATUS: NOT INSTALLED' "${TMP_DIR}/verify-host-only.out"; then
    pass_test 'verify.sh rejects the old host-only wrapper path'
  else
    fail_test 'verify.sh rejects the old host-only wrapper path with a clear state'
  fi
fi

mkdir -p "${MOCK_HOME_A}/.stremio-server"
printf '%s\n' legacy > "${LEGACY_A}"

printf '%s\n' 'UNSET_SERVER_PATH=1' > "${STATE_A}"
if run_with_env "${MOCK_HOME_A}" "${STATE_A}" "${MOCK_BIN}/flatpak" run --command=node com.stremio.Stremio -e stock-launch >"${TMP_DIR}/broken-stock-launch.out" 2>&1; then
  fail_test 'old unset SERVER_PATH state blocks the stock launcher'
else
  if ! grep -Fq '/app/libexec/stremio/server.js' "${TMP_DIR}/broken-stock-launch.out"; then
    pass_test 'old unset SERVER_PATH state blocks the stock launcher'
  else
    fail_test 'old unset SERVER_PATH state blocks the stock launcher clearly'
  fi
fi

if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${ROLLBACK}" >"${TMP_DIR}/rollback.out" 2>&1; then
  EFFECTIVE_STOCK=$(run_with_env "${MOCK_HOME_A}" "${STATE_A}" "${MOCK_BIN}/flatpak" run --command=node com.stremio.Stremio -e stock-launch)
  if grep -Fxq 'SERVER_PATH=/app/libexec/stremio/server.js' "${STATE_A}" \
    && [ ! -e "${CANONICAL_A}" ] \
    && [ ! -e "${LEGACY_A}" ] \
    && [ "${EFFECTIVE_STOCK}" = '/app/libexec/stremio/server.js' ]; then
    pass_test 'rollback restores stock SERVER_PATH, removes wrappers, and permits stock launch'
  else
    fail_test 'rollback restores stock SERVER_PATH, removes wrappers, and permits stock launch'
  fi
else
  cat "${TMP_DIR}/rollback.out" >&2
  fail_test 'rollback restores the stock path from an old unset state'
fi

if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${ROLLBACK}" >"${TMP_DIR}/rollback-repeat.out" 2>&1; then
  if grep -Fxq 'SERVER_PATH=/app/libexec/stremio/server.js' "${STATE_A}"; then
    pass_test 'rollback is idempotent and preserves the stock path'
  else
    fail_test 'rollback is idempotent and preserves the stock path'
  fi
else
  fail_test 'rollback is idempotent'
fi

if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${DIAGNOSE}" >"${TMP_DIR}/diagnose-stock.out" 2>&1; then
  if grep -Fq 'stock Stremio; Mute disabled' "${TMP_DIR}/diagnose-stock.out"; then
    pass_test 'diagnostics identify the verified stock post-rollback state'
  else
    fail_test 'diagnostics identify the verified stock post-rollback state'
  fi
else
  cat "${TMP_DIR}/diagnose-stock.out" >&2
  fail_test 'diagnostics run after rollback'
fi

STATE_B="${TMP_DIR}/state-b"
CANONICAL_B="${MOCK_HOME_B}/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js"
if run_with_env "${MOCK_HOME_B}" "${STATE_B}" bash "${INSTALLER}" >"${TMP_DIR}/install-b.out" 2>&1; then
  if grep -Fxq "SERVER_PATH=${CANONICAL_B}" "${STATE_B}" && [ -f "${CANONICAL_B}" ]; then
    pass_test 'different HOME values produce the corresponding canonical app-owned path'
  else
    fail_test 'different HOME values produce the corresponding canonical app-owned path'
  fi
else
  cat "${TMP_DIR}/install-b.out" >&2
  fail_test 'install.sh succeeds for a second HOME value'
fi

if run_with_env "${MOCK_HOME_B}" "${STATE_B}" bash "${INSTALLER}" >"${TMP_DIR}/install-b-repeat.out" 2>&1; then
  if grep -Fxq "SERVER_PATH=${CANONICAL_B}" "${STATE_B}"; then
    pass_test 'reinstall is idempotent and preserves the canonical path'
  else
    fail_test 'reinstall is idempotent and preserves the canonical path'
  fi
else
  fail_test 'reinstall is idempotent'
fi

if MOCK_EFFECTIVE_MISMATCH=1 run_with_env "${MOCK_HOME_B}" "${STATE_B}" bash "${ROLLBACK}" >"${TMP_DIR}/rollback-effective-failure.out" 2>&1; then
  fail_test 'rollback fails when effective SERVER_PATH differs from the override'
else
  if grep -Fxq "SERVER_PATH=${CANONICAL_B}" "${STATE_B}" \
    && [ -f "${CANONICAL_B}" ]; then
    pass_test 'rollback preserves the active wrapper on effective-path mismatch'
  else
    fail_test 'rollback preserves the active wrapper on effective-path mismatch'
  fi
fi

if MOCK_FAIL_STOCK_TARGET=1 run_with_env "${MOCK_HOME_B}" "${STATE_B}" bash "${ROLLBACK}" >"${TMP_DIR}/rollback-target-failure.out" 2>&1; then
  fail_test 'rollback fails when the stock server target is unavailable'
else
  if grep -Fxq "SERVER_PATH=${CANONICAL_B}" "${STATE_B}" \
    && [ -f "${CANONICAL_B}" ]; then
    pass_test 'rollback preserves the active wrapper when the stock target is unavailable'
  else
    fail_test 'rollback preserves the active wrapper when the stock target is unavailable'
  fi
fi

if MOCK_FAIL_STOCK_RESTORE=1 run_with_env "${MOCK_HOME_B}" "${STATE_B}" bash "${ROLLBACK}" >"${TMP_DIR}/rollback-failure.out" 2>&1; then
  fail_test 'rollback fails when stock-path restoration is unavailable'
else
  if grep -Fxq "SERVER_PATH=${CANONICAL_B}" "${STATE_B}" \
    && [ -f "${CANONICAL_B}" ]; then
    pass_test 'rollback preserves the active wrapper when stock-path restoration fails'
  else
    fail_test 'rollback preserves the active wrapper when stock-path restoration fails'
  fi
fi

if run_with_env "${MOCK_HOME_B}" "${STATE_B}" bash "${ROLLBACK}" >"${TMP_DIR}/rollback-b.out" 2>&1; then
  if grep -Fxq 'SERVER_PATH=/app/libexec/stremio/server.js' "${STATE_B}" \
    && [ ! -e "${CANONICAL_B}" ]; then
    pass_test 'rollback cleans the second installation after a failed attempt'
  else
    fail_test 'rollback cleans the second installation after a failed attempt'
  fi
else
  cat "${TMP_DIR}/rollback-b.out" >&2
  fail_test 'rollback cleans the second installation after a failed attempt'
fi

printf '%s\n' '================================================================================'
printf '%s\n' " CANONICAL FLATPAK PATH TESTS: ${pass_count} passed, ${fail_count} failed"
printf '%s\n' '================================================================================'
[ "${fail_count}" -eq 0 ]
