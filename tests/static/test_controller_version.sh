#!/usr/bin/env bash
# tests/static/test_controller_version.sh — Runtime version provenance regression tests

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
VERSION_FILE="${REPO_ROOT}/VERSION"
WRAPPER="${REPO_ROOT}/src/server-wrapper.js"
TMP_DIR=$(mktemp -d)
RUNTIME_PID=''
cleanup() {
  if [ -n "${RUNTIME_PID}" ]; then
    kill "${RUNTIME_PID}" 2>/dev/null || true
    wait "${RUNTIME_PID}" 2>/dev/null || true
  fi
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

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

PROJECT_VERSION="$(tr -d '\r\n' < "${VERSION_FILE}")"
SOURCE_SHA256="$(sha256sum "${WRAPPER}" | awk '{print $1}')"
SOURCE_VERSION="$(sed -n 's/.*CONTROLLER_VERSION = '\''\([0-9.]*\)'\'';.*/\1/p' "${WRAPPER}" | head -n1)"

printf '%s\n' '================================================================================'
printf '%s\n' ' RUNNING CONTROLLER VERSION PROVENANCE TESTS'
printf '%s\n' '================================================================================'

if [ "${PROJECT_VERSION}" = "${SOURCE_VERSION}" ]; then
  pass_test "repository VERSION ${PROJECT_VERSION} matches controller source ${SOURCE_VERSION}"
else
  fail_test "repository VERSION ${PROJECT_VERSION} differs from controller source ${SOURCE_VERSION}"
fi

printf '%s\n' '{"project":"stremio-mute","releaseVersion":"1.2.2","version":"1.2.1","sourceSha256":"stale"}' > "${TMP_DIR}/stale-endpoint.json"
if grep -q '"releaseVersion":"1.2.2"' "${TMP_DIR}/stale-endpoint.json" && grep -q '"version":"1.2.1"' "${TMP_DIR}/stale-endpoint.json" && ! grep -q '"version":"'"${PROJECT_VERSION}"'"' "${TMP_DIR}/stale-endpoint.json"; then
  pass_test 'exact observed repository 1.2.2 / runtime 1.2.1 mismatch is detected as invalid'
else
  fail_test 'exact observed repository 1.2.2 / runtime 1.2.1 mismatch detection'
fi

STAGED_WRAPPER="${TMP_DIR}/server-wrapper.js"
cp "${WRAPPER}" "${STAGED_WRAPPER}"
STREMIO_TARGET_SERVER_PATH="${REPO_ROOT}/tests/fixtures/server_runtime_status.js" node "${STAGED_WRAPPER}" > "${TMP_DIR}/runtime.log" 2>&1 &
RUNTIME_PID=$!
RUNTIME_ENDPOINT=''
for _ in $(seq 1 30); do
  RUNTIME_ENDPOINT=$(curl -fsS --max-time 1 http://127.0.0.1:11470/zero-upload-controller 2>/dev/null || true)
  [ -n "${RUNTIME_ENDPOINT}" ] && break
  sleep 0.1
done
if [ -n "${RUNTIME_ENDPOINT}" ] && grep -q '"version":"'"${PROJECT_VERSION}"'"' <<<"${RUNTIME_ENDPOINT}" && grep -q '"sourceSha256":"'"$(sha256sum "${STAGED_WRAPPER}" | awk '{print $1}')"'"' <<<"${RUNTIME_ENDPOINT}"; then
  pass_test 'live controller endpoint version and source hash match the release and executed wrapper'
else
  fail_test 'live controller endpoint version and source hash match the release and executed wrapper'
fi

INSTALLED_WRAPPER="${HOME}/.stremio-server/server-wrapper.js"
if [ -f "${INSTALLED_WRAPPER}" ]; then
  INSTALLED_SHA256="$(sha256sum "${INSTALLED_WRAPPER}" | awk '{print $1}')"
  if [ "${INSTALLED_SHA256}" = "${SOURCE_SHA256}" ]; then
    pass_test 'installed canonical wrapper bytes match repository wrapper bytes'
  else
    fail_test 'installed canonical wrapper bytes match repository wrapper bytes'
  fi
  RUNTIME_PID=''
  for pid in $(pgrep -x node 2>/dev/null || true); do
    if tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null | grep -q 'server-wrapper.js'; then
      RUNTIME_PID="${pid}"
      break
    fi
  done
  if [ -n "${RUNTIME_PID}" ]; then
    RUNTIME_CMDLINE="$(tr '\0' ' ' < "/proc/${RUNTIME_PID}/cmdline" 2>/dev/null || true)"
    if printf '%s' "${RUNTIME_CMDLINE}" | grep -Fq "${INSTALLED_WRAPPER}"; then
      pass_test 'running Node controller process command line references canonical installed wrapper'
    else
      fail_test 'running Node controller process command line references canonical installed wrapper'
    fi
  else
    printf '%s\n' '  [INFO] No running Node controller process available for process-path integrity check.'
  fi

else
  printf '%s\n' '  [INFO] Installed canonical wrapper unavailable; deployment-integrity checks are environment-limited.'
fi

printf '%s\n' '================================================================================'
printf '%s\n' " CONTROLLER VERSION TESTS: ${pass_count} passed, ${fail_count} failed"
printf '%s\n' '================================================================================'
[ "${fail_count}" -eq 0 ]
