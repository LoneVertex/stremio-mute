# Stremio Mute

> **Mute BitTorrent peer uploads. Keep streaming.**

[![CI](https://github.com/LoneVertex/stremio-mute/actions/workflows/ci.yml/badge.svg)](https://github.com/LoneVertex/stremio-mute/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Packaging: Linux Flatpak](https://img.shields.io/badge/Packaging-Linux%20Flatpak-orange.svg)](COMPATIBILITY.md)
[![Tested: Fedora KDE](https://img.shields.io/badge/Tested-Fedora%2044%20KDE-blue.svg)](COMPATIBILITY.md)
[![Status: Version--Sensitive](https://img.shields.io/badge/Compatibility-Version--Sensitive-yellow.svg)](COMPATIBILITY.md)

**Stremio Mute** is an application-level BitTorrent upload control utility for [Stremio](https://www.stremio.com/) on Linux (Flatpak). It suppresses media-piece uploads (seeding) to remote peers while streaming, preserving standard video playback, download throughput, and local player IPC communication.

---

## Quick Navigation

- [What It Does](#what-it-does)
- [Why It Exists](#why-it-exists)
- [How It Works](#how-it-works)
- [What It Does NOT Do](#what-it-does-not-do)
- [Compatibility](#compatibility)
- [Installation](#installation)
- [Operational Verification](#operational-verification)
- [Handling Stremio Updates](#handling-stremio-updates)
- [Rollback](#rollback)
- [Known Limitations](#known-limitations)
- [Architecture & Invariants](#architecture--invariants)
- [Security & Threat Model](#security--threat-model)
- [License & Trademarks](#license--trademarks)

---

## What It Does

- **Mutes Peer Piece Uploads:** Permanently chokes all BitTorrent peer connections (`rechokeSlots = 0`) and intercepts media request reads before cached disk chunks can be transmitted.
- **Preserves Full Video Downloads:** Outbound media block requests and downloads proceed normally whenever remote seeders unchoke the local client.
- **Preserves Local Player IPC:** Retains full desktop playback and loopback communication on `127.0.0.1:11470`.
- **Fails Closed on Update:** If Stremio updates and the internal engine layout changes, Stremio Mute aborts startup immediately with clear diagnostics rather than silently leaking upload bandwidth.

---

## Why It Exists

Stremio's embedded BitTorrent engine fork (`torrent-stream`) defaults to allocating 5 upload slots (`rechokeSlots = 5`). While streaming media, it actively reads downloaded chunks from disk cache and transmits them to remote peers. For users on metered, capped, or asymmetric ISP connections, this upstream traffic consumes quota and bandwidth. Stremio's settings UI currently lacks a functional engine-level zero-upload toggle.

---

## How It Works

1. Flatpak's native `SERVER_PATH` environment variable directs Stremio's launcher to load the staged wrapper in place of stock `server.js`. The installer stores the current user’s absolute path, such as `/home/current-user/.stremio-server/server-wrapper.js`.
2. The wrapper dynamically inspects `/app/libexec/stremio/server.js` in memory and verifies three structural code fingerprints.
3. The wrapper applies three in-memory modifications:
   - **`rechokeSlots = 0`**: Keeps all peer connections permanently choked (`wire.amChoking = true`).
   - **`defaults.uploads = 0`**: Sets engine constructor defaults to 0 upload slots.
   - **`wire.on("request")` Neutralization**: Intercepts incoming peer piece requests with an immediate policy error before disk reads can occur.
4. It compiles and executes the patched server in Node.js process memory without modifying any vendor files on disk.

---

## What It Does NOT Do

This project is strictly a local engine policy enforcement tool. It is **NOT**:
- A content provider, scraper, or streaming service.
- A Debrid client (Real-Debrid, AllDebrid, Premiumize, etc.).
- A third-party Stremio addon or catalog provider.
- An external proxy, VPN, or network relay.
- A tool that eliminates protocol discovery traffic (tracker announces exchanging ~200 bytes of discovery metadata remain active so peers can be located).

---

## Compatibility

| Layer | Environment | Status | Details |
|---|---|---|---|
| **Packaging** | Linux Flatpak (`com.stremio.Stremio`) | **Supported** | Standard Flathub distribution |
| **Tested Environment** | Fedora 44 + KDE Plasma 6 + Linux 7.1 | **VERIFIED** | Stremio v1.2.0 (EngineFS v4.21.0) |
| **Other Distributions** | Arch Linux, Ubuntu, Debian, openSUSE | **UNVERIFIED** | Expected to work via Flatpak; not independently tested |

For full compatibility definitions and fingerprint specifications, see [COMPATIBILITY.md](COMPATIBILITY.md).

---

## Installation

### Step 1: Clone the Repository
```bash
git clone https://github.com/LoneVertex/stremio-mute.git
cd stremio-mute
```

### Step 2: Run the Hardened Installer
```bash
./scripts/install.sh
```

**Pre-Flight Guarantee:** `install.sh` validates engine compatibility against Stremio's bundled `server.js` **before** staging the wrapper or applying the Flatpak override. If any fingerprint mismatches, installation aborts without altering your system.

---

## Operational Verification

Inspect operational state at any time:
```bash
./scripts/verify.sh
```

### State Semantics:
- **`STATUS: CONFIGURED`**: Static configuration is valid and Stremio is currently idle.
- **`STATUS: RUNTIME VERIFIED`**: Stremio is active and both the authoritative loopback controller endpoint and heartbeat confirm protected execution.
- **`STATUS: NOT PROTECTED`**: Stremio is running without complete controller and heartbeat evidence.
- **`STATUS: INCOMPATIBLE`**: Structural code fingerprints mismatched; the controller remains fail-closed.
- **`STATUS: NOT INSTALLED`**: The wrapper or exact absolute `SERVER_PATH` configuration is missing or incorrect.
- **`STATUS: ERROR`**: The verifier cannot safely determine the state.

### Absolute `SERVER_PATH` Rule

The shell expression `$HOME/.stremio-server/server-wrapper.js` is a shorthand used in documentation. The value persisted by Flatpak must be the dynamically computed absolute path for the current user, for example `/home/current-user/.stremio-server/server-wrapper.js`. Never write or expect `SERVER_PATH=~/.stremio-server/server-wrapper.js`; the literal tilde is not expanded by the Flatpak environment or Stremio’s Node process.

---

## Handling Stremio Updates

Because this tool relies on in-memory structural patching, it operates under a **Fail-Closed** safety model:

1. After running `flatpak update com.stremio.Stremio`, run:
   ```bash
   ./scripts/verify.sh
   ```
2. If verified, launch Stremio normally.
3. If an update altered `server.js` minification or layout, the controller **fails closed** (`process.exit(1)`) and outputs diagnostics. It will **never silently leak uploads**.
4. Run `./scripts/diagnose.sh` to generate an issue-safe report and submit a [Compatibility Report](https://github.com/LoneVertex/stremio-mute/issues).

---

## Rollback

To restore Stremio to standard default configuration:
```bash
./scripts/rollback.sh
```
This unsets the Flatpak environment override, deletes the canonical `$HOME/.stremio-server/server-wrapper.js` wrapper, removes any legacy sandbox-local wrapper from older releases, and actively verifies removal. Your library, addons, and user settings remain untouched.

---

## Known Limitations

1. **Version Sensitivity:** Relies on the internal JavaScript structure of Stremio's bundled `server.js`. Upstream code refactors will trigger fail-closed protection and require fingerprint updates.
2. **Tracker Discovery Metadata:** Exchanging ~200 bytes of tracker announce discovery metadata to locate seeders remains active as required by BitTorrent protocol mechanics.
3. **Flatpak Packaging Focus:** Designed specifically for Flatpak desktop installations on Linux.

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

## Security & Threat Model

- **No Elevated Privileges:** Executes purely in user space inside the unprivileged Flatpak sandbox (`0644` file permissions). Zero `sudo` or root permissions required.
- **Loopback Isolation:** Status endpoint (`/zero-upload-controller`) binds exclusively to `127.0.0.1` and exposes no user metadata or stream hashes.
- For complete security details, see [SECURITY.md](SECURITY.md) and [THREAT-MODEL.md](THREAT-MODEL.md).

---

## License & Trademarks

This repository's controller code and scripts are licensed under the [MIT License](LICENSE).  
*Stremio is a trademark and product of Smart Code LTD. This project is an independent open-source tool and is not affiliated with or endorsed by Smart Code LTD.*
