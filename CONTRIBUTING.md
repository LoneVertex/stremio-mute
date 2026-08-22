# Contributing to Stremio Mute

Thank you for your interest in contributing!

---

## Code of Conduct

All contributors are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Project Invariants & Non-Goals

Contributions must strictly align with the project's mission: **enforcing application-level BitTorrent peer-piece upload suppression on Linux Stremio while preserving normal playback and local IPC**. Deployment changes must preserve one canonical, app-owned Flatpak wrapper path and must not add broad filesystem permissions merely to make a host-only path work.

We do **NOT** accept contributions that:
- Integrate third-party Stremio addons, scrapers, indexers, or content providers.
- Integrate Debrid services (Real-Debrid, AllDebrid, Premiumize, etc.).
- Introduce external proxies, VPN wrappers, or streaming relays.
- Weaken fail-closed safety or remove exact-1 occurrence patch assertions.
- Modify Stremio vendor files directly on disk.

---

## Development & Testing Workflow

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/LoneVertex/stremio-mute.git
   cd stremio-mute
   ```
2. Run the test battery:
   ```bash
   find scripts tests -type f -name '*.sh' -print0 | xargs -0 shellcheck
   bash tests/static/test_syntax.sh
   bash tests/compatibility/test_compatibility_fixtures.sh
   bash tests/integration/test_install_rollback.sh
   bash tests/static/test_absolute_path.sh
   bash tests/static/test_controller_version.sh
   bash tests/static/test_stale_process_install.sh
   bash scripts/repo-audit.sh
   bash scripts/package.sh
   (cd dist && sha256sum -c SHA256SUMS)
   ```
3. When reporting runtime behavior, distinguish static tests from live Fedora/KDE/Flatpak evidence; include canonical-path visibility and legacy-cleanup evidence where relevant; do not claim `RUNTIME VERIFIED` or zero peer-piece upload without corresponding endpoint and environment evidence.
4. Submit a Pull Request following the [PR Template](.github/PULL_REQUEST_TEMPLATE.md).
