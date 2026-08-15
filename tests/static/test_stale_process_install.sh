#!/usr/bin/env bash
# tests/static/test_stale_process_install.sh — Stale-process deployment regression

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
TMP_DIR=$(mktemp -d)
MOCK_BIN="${TMP_DIR}/bin"
MOCK_HOME="${TMP_DIR}/home"
STATE_FILE="${TMP_DIR}/override.state"
RUNNING_FILE="${TMP_DIR}/running"
KILLED_FILE="${TMP_DIR}/killed"
mkdir -p "${MOCK_BIN}" "${MOCK_HOME}"
trap 'rm -rf "${TMP_DIR}"' EXIT

cat > "${MOCK_BIN}/flatpak" <<'MOCK_FLATPAK'
#!/usr/bin/env bash
set -u
STATE_FILE="${MOCK_STATE:?}"
RUNNING_FILE="${MOCK_RUNNING:?}"
KILLED_FILE="${MOCK_KILLED:?}"
mkdir -p "$(dirname "${STATE_FILE}")"
case "${1:-}" in
  info)
    exit 0
    ;;
  ps)
    if [ -f "${RUNNING_FILE}" ]; then
      printf '%s\n' 'com.stremio.Stremio'
    fi
    exit 0
    ;;
  kill)
    rm -f "${RUNNING_FILE}"
    : > "${KILLED_FILE}"
    exit 0
    ;;
  run)
    if printf '%s\n' "$*" | grep -Fq 'MATCH_EXACT_ONE'; then
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
        --show)
          [ -f "${STATE_FILE}" ] && cat "${STATE_FILE}"
          exit 0
          ;;
      esac
    done
    exit 0
    ;;
esac
exit 0
MOCK_FLATPAK
chmod +x "${MOCK_BIN}/flatpak"
: > "${RUNNING_FILE}"

if HOME="${MOCK_HOME}" MOCK_STATE="${STATE_FILE}" MOCK_RUNNING="${RUNNING_FILE}" MOCK_KILLED="${KILLED_FILE}" PATH="${MOCK_BIN}:${PATH}" bash "${REPO_ROOT}/scripts/install.sh" > "${TMP_DIR}/install.log" 2>&1; then
  if [ -f "${KILLED_FILE}" ] && [ ! -f "${RUNNING_FILE}" ]; then
    printf '%s\n' '[PASS] installer stops a running Stremio process before deployment'
  else
    printf '%s\n' '[FAIL] installer stops a running Stremio process before deployment' >&2
    exit 1
  fi
  if grep -Fq 'Existing Stremio process stopped' "${TMP_DIR}/install.log"; then
    printf '%s\n' '[PASS] installer reports stale-process prevention'
  else
    printf '%s\n' '[FAIL] installer reports stale-process prevention' >&2
    exit 1
  fi
else
  cat "${TMP_DIR}/install.log" >&2
  printf '%s\n' '[FAIL] installer succeeds in the stale-process mock' >&2
  exit 1
fi
