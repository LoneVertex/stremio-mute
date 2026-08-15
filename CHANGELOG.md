# Changelog — Stremio Mute

All notable changes to this project are documented in this file.

---

## [1.2.4] - 2026-08-15

### Fixed & Hardened
- **Flatpak-Aware Deployment:** The installer now stages the wrapper in app-owned per-user storage that is visible inside the `com.stremio.Stremio` sandbox instead of the host-only `$HOME/.stremio-server` location.
- **Canonical Runtime Path:** `install.sh`, `verify.sh`, `diagnose.sh`, and `rollback.sh` share one canonical absolute `SERVER_PATH` definition and prove sandbox visibility before accepting the installation.
- **Legacy Cleanup:** The installer and rollback remove only the project-managed legacy host wrapper, preventing competing active copies without touching unrelated Stremio data.
- **Verifier Path Correction:** `verify.sh` no longer misclassifies a working Flatpak-visible deployment as `NOT INSTALLED`; it rejects host-only, stale, incorrect, or invisible paths.
- **Runtime Identity Validation:** Runtime verification now requires the expected controller version, executing-wrapper `sourceSha256`, canonical path, heartbeat, active controller, and upload-suppression invariants.
- **Stale-Process Protection:** Installation continues to stop Stremio before deploying wrapper bytes so the next process cannot retain stale in-memory controller state.
- **Regression Coverage:** Added canonical-path, sandbox-visibility, host-only rejection, legacy-cleanup, lifecycle, runtime-identity, and stale-process coverage.
- **Documentation Synchronization:** Updated public installation, compatibility, troubleshooting, security, lifecycle, and support documentation for the repaired deployment model.

---

## [1.2.3] - 2026-08-15

### Fixed & Hardened
- **Stale Runtime Identity:** Fixed the observed repository `1.2.2` / runtime `1.2.1` mismatch by synchronizing the controller release identity with v1.2.3 and preventing an older in-memory process from surviving deployment.
- **Hardened Installer Lifecycle:** Installation stops a running Stremio process before replacing wrapper bytes, preventing stale-process execution after install, update, or reinstall.
- **Runtime Source Identity:** The loopback controller endpoint now exposes the controller `version` and executing-wrapper `sourceSha256` for deployment verification.
- **Tightened Runtime Verification:** `verify.sh` requires the endpoint version to match repository `VERSION` and `sourceSha256` to match the installed wrapper before reporting `RUNTIME VERIFIED`.
- **Regression Coverage:** Added an explicit failure case for the observed version mismatch and deployment-integrity checks where the environment permits.
- **Architecture Preserved:** Existing application-level upload suppression remains unchanged, including the `rechokeSlots = 0`, `uploads = 0`, and request-handler neutralization invariants.

---

## [1.2.2] - 2026-08-15

### Fixed & Hardened
- **Absolute Flatpak SERVER_PATH:** `install.sh` now computes the current user’s canonical wrapper path and stores the resulting absolute value instead of a literal tilde expression.
- **Exact Verifier Semantics:** `verify.sh` now rejects missing, literal-tilde, stale, cross-user, and incorrect paths while preserving the six-state model and requiring live controller and heartbeat evidence for runtime verification.
- **Lifecycle Cleanup:** Rollback removes the canonical wrapper and legacy sandbox-local wrapper path, and repeated install, rollback, and reinstall operations are covered by regression tests.
- **Permanent Regression Coverage:** Added isolated tests for multiple `HOME` values, correct and incorrect overrides, rollback, idempotence, and reinstall behavior.
- **Documentation Synchronization:** v1.2.2 documentation establishes the absolute-path rule across installation, runbook, troubleshooting, compatibility, and README guidance; subsequent documentation-only corrections continue to preserve that same published behavior without changing release assets.

---

## [1.2.1] - 2026-08-15

### Fixed & Hardened (Release-Blocker Remediation)
- **Positive Compatibility Fixture:** Fixed `tests/fixtures/server_supported.js` by adding mock runtime environment variables (`isPositiveInteger`, `opts`, `settings`, `uploadPipe`, `engine`) to allow clean in-memory compilation without throwing `ReferenceError`.
- **ShellCheck Compliance:** Resolved all ShellCheck warnings (SC2034, SC2016, SC2002) across all 9 shell scripts (`install.sh`, `verify.sh`, `diagnose.sh`, `rollback.sh`, `package.sh`, `repo-audit.sh`, `test_syntax.sh`, `test_compatibility_fixtures.sh`, `test_install_rollback.sh`).
- **Exact Override Value Assertion:** Hardened `scripts/verify.sh` to compare the stored `SERVER_PATH` value exactly; v1.2.2 corrects the prior release’s erroneous literal-tilde expectation to the required absolute path.
- **Decoupled Host Node Dependency:** Removed unnecessary host-side `command -v node` requirement from `scripts/install.sh`, relying solely on the sandbox Node.js runtime provided by Stremio Flatpak.
- **SPDX License Recognition:** Standardized `LICENSE` format for automatic GitHub SPDX `MIT` license detection.

---

## [1.2.0] - 2026-08-15

### Added & Changed
- **Project Identity:** Formally established open-source identity as **Stremio Mute** (`LoneVertex/stremio-mute`) — *Mute BitTorrent peer uploads. Keep streaming.*
- **Pre-Flight Installer:** Re-architected `scripts/install.sh` to run structural compatibility assertions against Stremio's bundled `server.js` before staging files or applying Flatpak overrides.
- **Authoritative State Verification:** Implemented 6-state machine in `scripts/verify.sh` (`NOT INSTALLED`, `CONFIGURED`, `RUNTIME VERIFIED`, `NOT PROTECTED`, `INCOMPATIBLE`, `ERROR`).
- **Exact-1 Fingerprint Matching:** Hardened structural compatibility assertions in `src/server-wrapper.js` to require that all 3 patch patterns match exactly 1 occurrence.
- **Fail-Closed Protection:** Terminate startup (`process.exit(1)`) with detailed diagnostics upon any code mismatch without silent fallback.
- **Dynamic User Resolution:** Fully parameterized user home directory resolution across all installation and rollback scripts.
- **Active Rollback Verification:** Enhanced `scripts/rollback.sh` to actively verify removal of overrides and wrapper files.

---

## [1.0.0] - 2026-08-14

### Initial Release
- Initial in-memory zero-upload controller for Stremio Linux Flatpak.
- Enforced `rechokeSlots = 0`, `defaults.uploads = 0`, and neutralized `wire.on("request")`.
- Basic Flatpak user environment override integration.
