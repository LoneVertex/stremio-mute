#!/usr/bin/env bash
# tests/static/test_absolute_path.sh — Canonical Flatpak-visible SERVER_PATH tests
# Reproduces the old host-only path failure through an isolated Flatpak mock.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
INSTALLER="${REPO_ROOT}/scripts/install.sh"
VERIFIER="${REPO_ROOT}/scripts/verify.sh"
ROLLBACK="${REPO_ROOT}/scripts/rollback.sh"
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
mkdir -p "$(dirname "${STATE_FILE}")"
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
      printf '%s\n' 'VISIBLE'
    elif printf '%s\n' "$*" | grep -Fq 'MATCH_EXACT_ONE'; then
      printf '%s\n' 'MATCH_EXACT_ONE'
    else
      printf '%s\n' 'COMPAT_OK'
    fi
    exit 0
    ;;
  override)
    for arg in "$@"; do
      case "${arg}" in
        --env=SERVER_PATH=*)
          printf '%s\n' "${arg#--env=}" > "${STATE_FILE}"
          exit 0
          ;;
        --unset-env=SERVER_PATH)
          rm -f "${STATE_FILE}"
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
  HOME="${home_dir}" MOCK_STATE="${state_file}" PATH="${MOCK_BIN}:${PATH}" "$@"
}

printf '%s\n' '================================================================================'
printf '%s\n' ' RUNNING CANONICAL FLATPAK PATH REGRESSION TESTS'
printf '%s\n' '================================================================================'

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
rm -f "${STATE_A}"
if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${ROLLBACK}" >"${TMP_DIR}/rollback.out" 2>&1; then
  if [ ! -e "${CANONICAL_A}" ] && [ ! -e "${LEGACY_A}" ] && [ ! -f "${STATE_A}" ]; then
    pass_test 'rollback removes canonical and legacy wrappers and exact override'
  else
    fail_test 'rollback removes canonical and legacy wrappers and exact override'
  fi
else
  cat "${TMP_DIR}/rollback.out" >&2
  fail_test 'rollback succeeds when state is already absent'
fi

if run_with_env "${MOCK_HOME_A}" "${STATE_A}" bash "${ROLLBACK}" >"${TMP_DIR}/rollback-repeat.out" 2>&1; then
  pass_test 'rollback is idempotent'
else
  fail_test 'rollback is idempotent'
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

printf '%s\n' '================================================================================'
printf '%s\n' " CANONICAL FLATPAK PATH TESTS: ${pass_count} passed, ${fail_count} failed"
printf '%s\n' '================================================================================'
[ "${fail_count}" -eq 0 ]
