# Contributing to Stremio Zero-Upload Controller

Thank you for your interest in contributing!

---

## Code of Conduct

All contributors are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Scope & Non-Goals

Contributions must strictly align with the project's mission: **enforcing zero BitTorrent piece upload policy on Linux Stremio while preserving normal playback and local IPC**.

We do **NOT** accept contributions that:
- Integrate third-party Stremio addons, scrapers, or indexers.
- Integrate Debrid services (Real-Debrid, AllDebrid, Premiumize, etc.).
- Introduce external proxies or streaming content relays.
- Weaken fail-closed safety or remove strict patch assertions.

---

## Development Workflow

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/venom010101/stremio-zero-upload.git
   cd stremio-zero-upload
   ```
2. Run the test suite:
   ```bash
   bash tests/static/test_syntax.sh
   bash tests/compatibility/test_compatibility_fixtures.sh
   ```
3. Run the repository auditor:
   ```bash
   bash scripts/repo-audit.sh
   ```
4. Submit a Pull Request following the [PR Template](.github/PULL_REQUEST_TEMPLATE.md).
