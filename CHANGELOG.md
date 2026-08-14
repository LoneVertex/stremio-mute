# Changelog — Stremio Zero-Upload Controller

All notable changes to this project are documented in this file.

---

## [1.2.0] - 2026-08-15

### Added
- **Exact-1 Fingerprint Matching:** Upgraded structural compatibility fingerprinting in `src/server-wrapper.js` to assert that every target pattern matches exactly 1 time in `server.js`.
- **Authoritative Loopback Telemetry:** Added `/zero-upload-controller` HTTP status endpoint on `127.0.0.1:11470` for deterministic health verification.
- **Fail-Closed Protection:** Terminate startup (`process.exit(1)`) with detailed diagnostics whenever structural code mismatch is detected.
- **Status Classification in `verify.sh`:** Clear differentiation between `STATUS: CONFIGURED (STATIC VALIDATION PASSED)` and `STATUS: RUNTIME VERIFIED (ZERO UPLOAD ENFORCED)`.
- **Dynamic Home Path Resolution:** Removed hardcoded user paths in `install.sh` and `verify.sh`.
- **Rollback Active Verification:** Added post-removal verification checks in `rollback.sh`.
- **Automated Test Suite:** Added static syntax tests (`tests/static/test_syntax.sh`) and compatibility test fixtures (`tests/compatibility/test_compatibility_fixtures.sh`).
- **Comprehensive Documentation:** Added full threat model, protocol architecture deep dive, runbook, and contributor guidelines.

---

## [1.0.0] - 2026-08-14

### Initial Release
- Initial in-memory zero-upload controller for Stremio Linux Flatpak.
- Enforced `rechokeSlots = 0`, `defaults.uploads = 0`, and neutralized `wire.on("request")`.
- Basic Flatpak user environment override integration.
