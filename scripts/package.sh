#!/usr/bin/env bash
# scripts/package.sh — Release Archive Generator
# Builds deterministic release tarball and zip archives with SHA-256 checksums.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
VERSION=$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")
ARCHIVE_BASE="stremio-zero-upload-v${VERSION}"

echo "================================================================================"
echo " STREMIO ZERO-UPLOAD — RELEASE PACKAGER (v${VERSION})"
echo "================================================================================"

mkdir -p "$DIST_DIR"
rm -rf "${DIST_DIR:?}"/*

# 1. Pre-flight audit
echo "[1/4] Running repository audit..."
bash "${SCRIPT_DIR}/repo-audit.sh"

# 2. Stage distribution payload
echo "[2/4] Staging distribution files..."
STAGE_DIR="${DIST_DIR}/${ARCHIVE_BASE}"
mkdir -p "${STAGE_DIR}/src" "${STAGE_DIR}/scripts" "${STAGE_DIR}/docs/operations"

cp "${REPO_ROOT}/README.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/LICENSE" "${STAGE_DIR}/"
cp "${REPO_ROOT}/SECURITY.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/INSTALL.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/ARCHITECTURE.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/THREAT-MODEL.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/COMPATIBILITY.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/TROUBLESHOOTING.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/CHANGELOG.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/VERSION" "${STAGE_DIR}/"

cp "${REPO_ROOT}/src/server-wrapper.js" "${STAGE_DIR}/src/"
cp "${REPO_ROOT}/scripts/install.sh" "${STAGE_DIR}/scripts/"
cp "${REPO_ROOT}/scripts/verify.sh" "${STAGE_DIR}/scripts/"
cp "${REPO_ROOT}/scripts/rollback.sh" "${STAGE_DIR}/scripts/"
cp "${REPO_ROOT}/scripts/diagnose.sh" "${STAGE_DIR}/scripts/"
cp "${REPO_ROOT}/docs/operations/RUNBOOK.md" "${STAGE_DIR}/docs/operations/"

# 3. Create archives
echo "[3/4] Creating release archives..."
cd "$DIST_DIR"
tar -czvf "${ARCHIVE_BASE}.tar.gz" "${ARCHIVE_BASE}"
zip -r "${ARCHIVE_BASE}.zip" "${ARCHIVE_BASE}"
rm -rf "${ARCHIVE_BASE}"

# 4. Generate checksums
echo "[4/4] Generating SHA-256 checksums..."
sha256sum "${ARCHIVE_BASE}.tar.gz" "${ARCHIVE_BASE}.zip" > "SHA256SUMS"

echo ""
echo "================================================================================"
echo " RELEASE ARTIFACTS GENERATED IN: ${DIST_DIR}"
echo "================================================================================"
cat "SHA256SUMS"
echo "================================================================================"
