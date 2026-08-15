#!/usr/bin/env bash
# scripts/repo-audit.sh — Stremio Mute Repository Hygiene, Secrets & Artifact Auditor
# Verifies repository cleanliness, required files, syntax, and absence of private/agent artifacts.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ERRORS=0
WARNS=0

echo "================================================================================"
echo " STREMIO MUTE — REPOSITORY AUDITOR"
echo "================================================================================"

# ── 1. Required Project Files ──────────────────────────────────────────────────
echo ""
echo "── 1. Required Project Files ──────────────────────────────────────────────────"

REQUIRED_FILES=(
  "README.md"
  "LICENSE"
  "SECURITY.md"
  "CONTRIBUTING.md"
  "CODE_OF_CONDUCT.md"
  "CHANGELOG.md"
  "SUPPORT.md"
  "INSTALL.md"
  "ARCHITECTURE.md"
  "THREAT-MODEL.md"
  "COMPATIBILITY.md"
  "TROUBLESHOOTING.md"
  "FAQ.md"
  "VERSIONING.md"
  "THIRD-PARTY.md"
  "VERSION"
  ".gitignore"
  ".gitattributes"
  ".editorconfig"
  "src/server-wrapper.js"
  "scripts/install.sh"
  "scripts/verify.sh"
  "scripts/rollback.sh"
  "scripts/diagnose.sh"
  "scripts/package.sh"
  "docs/operations/RUNBOOK.md"
  ".github/workflows/ci.yml"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "${REPO_ROOT}/${file}" ]; then
    echo "  [PASS] Required file present: ${file}"
  else
    echo "  [FAIL] Missing required file: ${file}" >&2
    ERRORS=$((ERRORS+1))
  fi
done

# ── 2. Legacy & Forbidden Artifacts Check ──────────────────────────────────────
echo ""
echo "── 2. Legacy & Forbidden Artifacts Check ──────────────────────────────────"

FORBIDDEN_PATTERNS=("*.nft" "*.service" "*firewalld*" "*.log" "*.swp" ".DS_Store")
for pat in "${FORBIDDEN_PATTERNS[@]}"; do
  MATCHES=$(find "${REPO_ROOT}" -name "${pat}" -not -path '*/.git/*' 2>/dev/null || true)
  if [ -z "${MATCHES}" ]; then
    echo "  [PASS] No '${pat}' artifacts found"
  else
    echo "  [FAIL] Found forbidden artifacts for '${pat}':" >&2
    echo "${MATCHES}" >&2
    ERRORS=$((ERRORS+1))
  fi
done

# ── 3. Secrets & Private Identity Scrubbing ────────────────────────────────────
echo ""
echo "── 3. Secrets & Private Identity Scrubbing ──────────────────────────────────"

# Check for hardcoded private local machine paths
PRIVATE_PATHS=$(grep -rn "home/lonevertex" "${REPO_ROOT}" \
  --exclude-dir=".git" \
  --exclude-dir="dist" \
  --exclude="repo-audit.sh" \
  --exclude="RUNBOOK.md" \
  --exclude="README.md" \
  2>/dev/null || true)

if [ -z "${PRIVATE_PATHS}" ]; then
  echo "  [PASS] No private local machine paths detected"
else
  echo "  [FAIL] Detected hardcoded private paths:" >&2
  echo "${PRIVATE_PATHS}" >&2
  ERRORS=$((ERRORS+1))
fi

# Check for tokens, private keys
SECRET_MATCHES=$(grep -rEi "BEGIN (RSA |OPENSSH )?PRIVATE KEY|ghp_[a-zA-Z0-9]{30,}|gho_[a-zA-Z0-9]{30,}" "${REPO_ROOT}" \
  --exclude-dir=".git" \
  --exclude-dir="dist" 2>/dev/null || true)

if [ -z "${SECRET_MATCHES}" ]; then
  echo "  [PASS] No private keys or tokens detected"
else
  echo "  [FAIL] Potential secret leakage detected:" >&2
  echo "${SECRET_MATCHES}" >&2
  ERRORS=$((ERRORS+1))
fi

# ── 4. Shell & JavaScript Syntax Validation ────────────────────────────────────
echo ""
echo "── 4. Shell & JavaScript Syntax Validation ──────────────────────────────────"

while IFS= read -r sh_file; do
  if bash -n "$sh_file" 2>/dev/null; then
    echo "  [PASS] Shell syntax OK: ${sh_file#"${REPO_ROOT}/"}"
  else
    echo "  [FAIL] Shell syntax error: ${sh_file#"${REPO_ROOT}/"}" >&2
    ERRORS=$((ERRORS+1))
  fi
done < <(find "${REPO_ROOT}" -type f -name "*.sh" -not -path '*/.git/*')

while IFS= read -r js_file; do
  if node -c "$js_file" 2>/dev/null; then
    echo "  [PASS] JS syntax OK: ${js_file#"${REPO_ROOT}/"}"
  else
    echo "  [FAIL] JS syntax error: ${js_file#"${REPO_ROOT}/"}" >&2
    ERRORS=$((ERRORS+1))
  fi
done < <(find "${REPO_ROOT}" -type f -name "*.js" -not -path '*/.git/*')

# ── 5. Version Consistency ────────────────────────────────────────────────────
echo ""
echo "── 5. Version Consistency ──────────────────────────────────────────────────"

VERSION_FILE_VAL=$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")
WRAPPER_VERSION_VAL=$(grep "CONTROLLER_VERSION = " "${REPO_ROOT}/src/server-wrapper.js" | head -n1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")

if [ "${VERSION_FILE_VAL}" = "${WRAPPER_VERSION_VAL}" ]; then
  echo "  [PASS] Version synchronized across VERSION (${VERSION_FILE_VAL}) and src/server-wrapper.js (${WRAPPER_VERSION_VAL})"
else
  echo "  [FAIL] Version mismatch: VERSION=${VERSION_FILE_VAL} vs wrapper=${WRAPPER_VERSION_VAL}" >&2
  ERRORS=$((ERRORS+1))
fi

echo ""
echo "================================================================================"
if [ "$ERRORS" -eq 0 ]; then
  echo " AUDIT PASSED (Errors: 0, Warnings: ${WARNS})"
  echo " Repository is clean, compliant, and ready for release."
  echo "================================================================================"
  exit 0
else
  echo " AUDIT FAILED (Errors: ${ERRORS}, Warnings: ${WARNS})" >&2
  echo "================================================================================"
  exit 1
fi
