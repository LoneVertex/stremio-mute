#!/usr/bin/env bash
# scripts/package.sh — Stremio Mute Release Packager
# Generates release tarball, zip, and SHA256SUMS manifest for GitHub Releases.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
VERSION=$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")
PKG_NAME="stremio-mute-v${VERSION}"
STAGE_DIR="/tmp/${PKG_NAME}"

echo "================================================================================"
echo " STREMIO MUTE — RELEASE PACKAGER (v${VERSION})"
echo "================================================================================"

# 1. Run repo audit before packaging
echo "[1/4] Running repository audit..."
bash "${SCRIPT_DIR}/repo-audit.sh"

# 2. Stage clean release files
echo "[2/4] Staging distribution files..."
rm -rf "${DIST_DIR}" "${STAGE_DIR}"
mkdir -p "${DIST_DIR}" "${STAGE_DIR}"

# Copy tracked repository files into stage directory
mkdir -p "${STAGE_DIR}/src" "${STAGE_DIR}/scripts" "${STAGE_DIR}/docs/operations"

cp "${REPO_ROOT}/src/server-wrapper.js" "${STAGE_DIR}/src/"
cp "${REPO_ROOT}/scripts/install.sh" "${STAGE_DIR}/scripts/"
cp "${REPO_ROOT}/scripts/verify.sh" "${STAGE_DIR}/scripts/"
cp "${REPO_ROOT}/scripts/rollback.sh" "${STAGE_DIR}/scripts/"
cp "${REPO_ROOT}/scripts/diagnose.sh" "${STAGE_DIR}/scripts/"
cp "${REPO_ROOT}/scripts/runtime-path.sh" "${STAGE_DIR}/scripts/"
cp "${REPO_ROOT}/docs/operations/RUNBOOK.md" "${STAGE_DIR}/docs/operations/"
cp "${REPO_ROOT}/README.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/LICENSE" "${STAGE_DIR}/"
cp "${REPO_ROOT}/SECURITY.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/INSTALL.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/ARCHITECTURE.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/THREAT-MODEL.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/COMPATIBILITY.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/TROUBLESHOOTING.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/CHANGELOG.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/FAQ.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/SUPPORT.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/THIRD-PARTY.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/VERSIONING.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/CODE_OF_CONDUCT.md" "${STAGE_DIR}/"
cp "${REPO_ROOT}/VERSION" "${STAGE_DIR}/"

# Set permissions
chmod 755 "${STAGE_DIR}/scripts/"*.sh
chmod 644 "${STAGE_DIR}/src/"*.js "${STAGE_DIR}/"*.md "${STAGE_DIR}/VERSION" "${STAGE_DIR}/docs/operations/"*.md

# 3. Create deterministic release archives
echo "[3/4] Creating deterministic release archives..."
find "${STAGE_DIR}" -exec touch -h -d '@0' {} +
cd /tmp
tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner -czf "${DIST_DIR}/${PKG_NAME}.tar.gz" "${PKG_NAME}"
find "${PKG_NAME}" -print | LC_ALL=C sort | zip -X -q "${DIST_DIR}/${PKG_NAME}.zip" -@

# Clean temporary stage
rm -rf "${STAGE_DIR}"

# 4. Generate SHA256SUMS
echo "[4/4] Generating SHA-256 checksums..."
cd "${DIST_DIR}"
sha256sum "${PKG_NAME}.tar.gz" "${PKG_NAME}.zip" > SHA256SUMS

echo ""
echo "================================================================================"
echo " RELEASE ARTIFACTS GENERATED IN: ${DIST_DIR}"
echo "================================================================================"
cat "${DIST_DIR}/SHA256SUMS"
echo "================================================================================"
