# Stremio Zero-Upload Controller

[![CI](https://github.com/venom010101/stremio-zero-upload/actions/workflows/ci.yml/badge.svg)](https://github.com/venom010101/stremio-zero-upload/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Linux Flatpak](https://img.shields.io/badge/Platform-Linux%20Flatpak-orange.svg)](COMPATIBILITY.md)
[![Status: Version--Sensitive](https://img.shields.io/badge/Compatibility-Version--Sensitive-yellow.svg)](COMPATIBILITY.md)

**Stremio Zero-Upload Controller** is a local, engine-level policy enforcement tool for [Stremio](https://www.stremio.com/) on Linux (Flatpak). It suppresses BitTorrent peer-piece uploads (seeding) while streaming, preserving standard video playback, download throughput, and local player IPC communication.

---

## Quick Navigation

- [What Is This?](#what-is-this)
- [What Problem Does It Solve?](#what-problem-does-it-solve)
- [How Does It Work?](#how-does-it-work)
- [What Does It NOT Do?](#what-does-it-not-do)
- [Supported Platforms](#supported-platforms)
- [Quick Start: Installation & Verification](#quick-start-installation--verification)
- [Handling Stremio Updates](#handling-stremio-updates)
- [Rollback](#rollback)
- [Architecture & Invariants](#architecture--invariants)
- [Documentation Index](#documentation-index)

---

## What Is This?

A lightweight in-memory wrapper for Stremio's embedded streaming server (`server.js`) that injects zero-upload invariants into the BitTorrent engine at process startup via a standard Flatpak user environment override.

## What Problem Does It Solve?

Stremio's embedded BitTorrent engine (`torrent-stream`) defaults to allocating 5 upload slots (`rechokeSlots = 5`). While streaming media, it actively serves downloaded chunks from disk cache to remote peers. For users on metered, capped, or asymmetric ISP connections, this upload traffic consumes upstream bandwidth and ISP quota. Stremio's settings UI currently lacks a working native zero-upload toggle.

## How Does It Work?

1. Flatpak's native `SERVER_PATH` environment variable directs Stremio's launcher to load `src/server-wrapper.js` in place of stock `server.js`.
2. The wrapper dynamically inspects `/app/libexec/stremio/server.js` in memory and verifies three structural code fingerprints.
3. The wrapper applies three in-memory modifications:
   - **`rechokeSlots = 0`**: Permanently keeps all peer connections choked (`wire.amChoking = true`).
   - **`defaults.uploads = 0`**: Sets engine constructor defaults to 0 upload slots.
   - **`wire.on("request")` Neutralization**: Intercepts incoming peer piece requests with an immediate policy error before disk reads can occur.
4. It compiles and executes the patched server in Node.js process memory without modifying any vendor files on disk.

## What Does It NOT Do?

This project is strictly a local engine policy enforcement tool. It is **NOT**:
- A content provider or streaming service
- A Debrid client (Real-Debrid, AllDebrid, Premiumize, etc.)
- A third-party addon, community addon, or scraper
- A proxy or relay service
- A modification to the Stremio desktop UI

## Supported Platforms

- **Operating System:** Linux (Fedora, Arch Linux, Ubuntu, Debian, openSUSE, etc.)
- **Desktop Environment:** KDE Plasma, GNOME, XFCE, etc.
- **Packaging:** Stremio Flatpak (`com.stremio.Stremio` from Flathub)
- **Tested Stremio Version:** `v1.2.0` (EngineFS v4.21.0 / `torrent-stream`)

---

## Quick Start: Installation & Verification

### 1. Clone the Repository
```bash
git clone https://github.com/venom010101/stremio-zero-upload.git
cd stremio-zero-upload
```

### 2. Install Controller
```bash
./scripts/install.sh
```

### 3. Verify Operational Status
```bash
./scripts/verify.sh
```

Expected output:
```text
================================================================================
 STATUS: CONFIGURED (STATIC VALIDATION PASSED)
 Verdict: Zero-upload controller is correctly installed and ready.
          Start Stremio to verify runtime protection.
================================================================================
```

When Stremio is launched and running:
```text
================================================================================
 STATUS: RUNTIME VERIFIED (ZERO UPLOAD ENFORCED)
 Verdict: Stremio server is running with active zero-upload controller v1.2.0.
================================================================================
```

---

## Handling Stremio Updates

Because this solution relies on in-memory patching of `server.js`, it is classified as **Version-Sensitive**:

- **Fail-Closed Protection:** If an upstream Stremio update modifies `server.js` such that any fingerprint does not match exactly once, the controller **aborts startup immediately (`process.exit(1)`)** with clear diagnostics. It will **never silently leak uploads**.
- **Post-Update Verification:** After running `flatpak update com.stremio.Stremio`, run:
  ```bash
  ./scripts/verify.sh
  ```
  If verified, launch Stremio normally. If incompatible, refer to [COMPATIBILITY.md](COMPATIBILITY.md).

---

## Rollback

To restore Stremio to standard default configuration:
```bash
./scripts/rollback.sh
```

---

## Architecture & Invariants

```text
REMOTE PEER WIRE
      │
      ├── [1] Incoming Piece Data (wire._onpiece) ────────► LOCAL DISK CACHE ✅ (Download Active)
      │
      ├── [2] Incoming Request (wire._onrequest) ────────► REJECTED by amChoking = true ❌
      │
      └── [3] Handler uploadPipe.push(store.read) ──────► BLOCKED by policy error ❌
```

For full protocol analysis and details on why network-layer filtering (nftables/conntrack) was rejected, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Documentation Index

- [Installation Guide](INSTALL.md)
- [Architecture & Protocol Analysis](ARCHITECTURE.md)
- [Threat Model & Security Guarantees](THREAT-MODEL.md)
- [Compatibility Matrix & Update Model](COMPATIBILITY.md)
- [Operational Runbook](docs/operations/RUNBOOK.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Frequently Asked Questions (FAQ)](FAQ.md)
- [Security Policy](SECURITY.md)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

---

## License

This repository's controller code and scripts are licensed under the [MIT License](LICENSE).  
*Stremio is a trademark and product of Smart Code LTD. This project is an independent open-source tool and is not affiliated with or endorsed by Smart Code LTD.*
