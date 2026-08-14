# Changelog — Stremio Mute

All notable changes to this project are documented in this file.

---

## [1.2.0] - 2026-08-15

### Changed & Hardened
- **Project Identity:** Formally established open-source identity as **Stremio Mute** (`LoneVertex/stremio-mute`) — *Mute BitTorrent peer uploads. Keep streaming.*
- **Pre-Flight Installer:** Re-architected `scripts/install.sh` to run structural compatibility assertions against Stremio's bundled `server.js` **before** staging files or applying Flatpak overrides, failing cleanly if incompatible.
- **Authoritative State Verification:** Implemented explicit state machine in `scripts/verify.sh` (`NOT INSTALLED`, `CONFIGURED`, `RUNTIME VERIFIED`, `NOT PROTECTED`, `INCOMPATIBLE`, `ERROR`) utilizing `flatpak override --user --show` as the primary source of truth.
- **Exact-1 Fingerprint Matching:** Hardened structural compatibility assertions in `src/server-wrapper.js` to require that all 3 patch patterns match exactly 1 occurrence in `server.js`.
- **Fail-Closed Protection:** Terminate startup (`process.exit(1)`) with detailed diagnostics upon any code mismatch without silent fallback.
- **Dynamic User Resolution:** Fully parameterized user home directory resolution across all installation and rollback scripts.
- **Active Rollback Verification:** Enhanced `scripts/rollback.sh` to actively verify that the Flatpak override and sandboxed wrapper files were completely removed.
- **Automated Test Battery:** Added static syntax tests, fail-closed compatibility test fixtures, and integration test runners.
- **Sanitized Diagnostics:** Added `scripts/diagnose.sh` to generate issue-safe diagnostic summaries.
- **Comprehensive Documentation:** Added complete threat model, architecture protocol analysis, operational runbook, and contributor guidelines.

---

## [1.0.0] - 2026-08-14

### Initial Release
- Initial in-memory zero-upload controller for Stremio Linux Flatpak.
- Enforced `rechokeSlots = 0`, `defaults.uploads = 0`, and neutralized `wire.on("request")`.
- Basic Flatpak user environment override integration.
