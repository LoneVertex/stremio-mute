#!/usr/bin/env bash
# scripts/repo-audit.sh — Repository Quality, Hygiene, and Security Auditor
# Audits the repository for required files, syntax validity, hardcoded paths, secrets, and legacy artifacts.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ERRORS=0
WARNINGS=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1" >&2; ERRORS=$((ERRORS+1)); }
warn() { echo "  [WARN] $1"; WARNINGS=$((WARNINGS+1)); }
header() { echo ""; echo "── $1 ──────────────────────────────────────────────────────────"; }

echo "================================================================================"
echo " STREMIO ZERO-UPLOAD — REPOSITORY AUDITOR"
echo "================================================================================"

header "1. Required Project Files"
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
    pass "Required file present: ${file}"
  else
    fail "Missing required file: ${file}"
  fi
done

header "2. Legacy & Forbidden Artifacts Check"
FORBIDDEN_PATTERNS=(
  "*.nft"
  "*.service"
  "*firewalld*"
  "*.log"
  "*.swp"
  ".DS_Store"
)

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
  MATCHES=$(find "${REPO_ROOT}" -name "${pattern}" -not -path '*/.git/*' 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    fail "Forbidden artifact pattern '${pattern}' detected: $MATCHES"
  else
    pass "No '${pattern}' artifacts found"
  fi
done

header "3. Secrets & Private Identity Scrubbing"
# Search for private machine paths or API tokens
MATCH_PATHS=$(grep -rn "lonevertex" "${REPO_ROOT}" \
  --exclude-dir=".git" \
  --exclude="repo-audit.sh" 2>/dev/null || true)

if [ -n "$MATCH_PATHS" ]; then
  fail "Private username/path found in tracked files:\n${MATCH_PATHS}"
else
  pass "No private local machine paths detected"
fi

# Secret patterns
MATCH_KEYS=$(grep -rEi "BEGIN (RSA|OPENSSH|EC|DSA)? PRIVATE KEY|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9]{50,}" "${REPO_ROOT}" \
  --exclude-dir=".git" 2>/dev/null || true)

if [ -n "$MATCH_KEYS" ]; then
  fail "Potential secret/key detected:\n${MATCH_KEYS}"
else
  pass "No private keys or tokens detected"
fi

header "4. Shell & JavaScript Syntax Validation"
# Validate all bash scripts
while IFS= read -r script; do
  if bash -n "$script" 2>/dev/null; then
    pass "Shell syntax OK: ${script#"${REPO_ROOT}/"}"
  else
    fail "Shell syntax error in: ${script#"${REPO_ROOT}/"}"
  fi
done < <(find "${REPO_ROOT}" -type f -name "*.sh" -not -path '*/.git/*')

# Validate all JS files
while IFS= read -r jsfile; do
  if node -c "$jsfile" 2>/dev/null; then
    pass "JS syntax OK: ${jsfile#"${REPO_ROOT}/"}"
  else
    fail "JS syntax error in: ${jsfile#"${REPO_ROOT}/"}"
  fi
done < <(find "${REPO_ROOT}" -type f -name "*.js" -not -path '*/.git/*')

header "5. Version Consistency"
if [ -f "${REPO_ROOT}/VERSION" ]; then
  CANONICAL_VER=$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")
  WRAPPER_VER=$(grep "CONTROLLER_VERSION = " "${REPO_ROOT}/src/server-wrapper.js" | head -1 | cut -d"'" -f2 || echo "")
  if [ "$CANONICAL_VER" = "$WRAPPER_VER" ]; then
    pass "Version synchronized across VERSION (${CANONICAL_VER}) and src/server-wrapper.js (${WRAPPER_VER})"
  else
    fail "Version mismatch: VERSION=${CANONICAL_VER} vs server-wrapper.js=${WRAPPER_VER}"
  fi
else
  fail "VERSION file missing"
fi

echo ""
echo "================================================================================"
if [ "$ERRORS" -eq 0 ]; then
  echo " AUDIT PASSED (Errors: 0, Warnings: ${WARNINGS})"
  echo " Repository is clean, compliant, and ready for release."
  echo "================================================================================"
  exit 0
else
  echo " AUDIT FAILED (Errors: ${ERRORS}, Warnings: ${WARNINGS})"
  echo " Please address the issues listed above."
  echo "================================================================================"
  exit 1
fi
