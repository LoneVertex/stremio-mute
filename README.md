# Stremio Mute

> **Mute BitTorrent peer uploads. Keep streaming.**

[![CI](https://github.com/LoneVertex/stremio-mute/actions/workflows/ci.yml/badge.svg)](https://github.com/LoneVertex/stremio-mute/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Packaging: Linux Flatpak](https://img.shields.io/badge/Packaging-Linux%20Flatpak-orange.svg)](COMPATIBILITY.md)
[![Tested: Fedora KDE](https://img.shields.io/badge/Tested-Fedora%2044%20KDE-blue.svg)](COMPATIBILITY.md)
[![Status: Version--Sensitive](https://img.shields.io/badge/Compatibility-Version--Sensitive-yellow.svg)](COMPATIBILITY.md)

**Stremio Mute** is an application-level BitTorrent upload-control utility for [Stremio](https://www.stremio.com/) on Linux Flatpak. It suppresses media-piece uploads to remote peers while preserving ordinary video playback, download throughput, and local player IPC communication.

---

## Quickstart

Use the published v1.2.3 checkout for a reproducible installation:

```bash
git clone https://github.com/LoneVertex/stremio-mute.git
cd stremio-mute
git checkout v1.2.3
./scripts/install.sh
./scripts/verify.sh
```

When Stremio is stopped, a correct installation reports `STATUS: CONFIGURED`. Launch Stremio normally, start a stream, and verify the running state:

```bash
flatpak run com.stremio.Stremio
./scripts/verify.sh
```

A protected running server reports `STATUS: RUNTIME VERIFIED`. After every Stremio or Flatpak update, run `./scripts/verify.sh` before streaming. After a reboot, `CONFIGURED` before launch is normal; `RUNTIME VERIFIED` requires the Stremio server to be running and its controller and heartbeat to respond.

For complete procedures, see [INSTALL.md](INSTALL.md) and the [operational runbook](docs/operations/RUNBOOK.md).

---

## What It Does

- **Mutes peer piece uploads:** Permanently chokes BitTorrent peer connections and intercepts media request reads before cached disk chunks can be transmitted.
- **Preserves video downloads:** Outbound media block requests and downloads proceed normally whenever remote seeders unchoke the local client.
- **Preserves local player IPC:** Retains desktop playback and loopback communication on `127.0.0.1:11470`.
- **Fails closed on update:** If Stremio updates and the internal engine layout changes, Stremio Mute aborts startup with diagnostics rather than silently permitting unverified upload behavior.

## Why It Exists

Stremio’s embedded BitTorrent engine fork defaults to allocating upload slots. While streaming media, it can read downloaded chunks from its cache and transmit them to remote peers. Stremio’s settings UI does not provide a reliable engine-level zero-upload control, so Stremio Mute applies that policy at the controller layer for the Flatpak server process.

---

## How It Works

1. Flatpak’s `SERVER_PATH` environment variable directs Stremio’s launcher to the staged wrapper instead of stock `server.js`.
2. The installer stops any running Stremio process, stages the wrapper at `$HOME/.stremio-server/server-wrapper.js`, and stores the **expanded absolute path** in the Flatpak user override. Stopping first ensures the next launch cannot retain an older in-memory controller version. For example, the persisted value may be `/home/current-user/.stremio-server/server-wrapper.js`.
3. The wrapper inspects `/app/libexec/stremio/server.js` in memory and requires three structural fingerprints to occur exactly once.
4. It applies three in-memory modifications: `rechokeSlots = 0`, engine defaults `uploads = 0`, and request-handler neutralization before disk-piece reads.
5. It compiles and executes the patched server in Node.js process memory without modifying vendor files on disk.

### Absolute `SERVER_PATH` Rule

Use `$HOME/.stremio-server/server-wrapper.js` in shell commands when referring to the current user’s home directory. The Flatpak environment value itself is stored as an absolute path and must not contain a literal tilde. This is correct:

```text
SERVER_PATH=/home/current-user/.stremio-server/server-wrapper.js
```

This is the historical invalid form and must not be configured:

```text
SERVER_PATH=~/.stremio-server/server-wrapper.js
```

---

## What It Does Not Do

This project is a local engine-policy enforcement tool. It is not a content provider, scraper, streaming service, Debrid client, third-party addon, catalog provider, proxy, VPN, or network relay. It does not eliminate the minimal protocol discovery traffic needed to locate seeders.

---

## Compatibility

| Layer | Environment | Status | Details |
|---|---|---|---|
| **Packaging** | Linux Flatpak (`com.stremio.Stremio`) | **SUPPORTED** | Standard Flathub distribution mechanism |
| **Controller** | Stremio Mute v1.2.3 | **CURRENT** | Fail-closed wrapper with exact-one structural fingerprints |
| **Verified environment** | Fedora 44 + KDE Plasma 6 + Linux 7.1 | **VERIFIED** | Stremio v1.2.0 / EngineFS v4.21.0; this is the verified target evidence, not the controller version |
| **Other distributions** | Arch Linux, Ubuntu, Debian, openSUSE | **UNVERIFIED** | Expected to work through Flatpak but not independently tested by this project |
| **Native packages** | `.deb`, `.rpm`, AUR, AppImage | **OUT OF SCOPE** | The implementation is designed for the Flatpak user override |

See [COMPATIBILITY.md](COMPATIBILITY.md) for fingerprint definitions and update behavior.

---

## Verification States

Run:

```bash
./scripts/verify.sh
```

- **`CONFIGURED`** means the static wrapper, exact absolute override, source match, and compatibility checks are valid while Stremio is idle.
- **`RUNTIME VERIFIED`** means Stremio is running and the controller endpoint and heartbeat confirm protected execution, while the endpoint version matches `VERSION` and its source SHA256 matches the installed wrapper.
- **`NOT PROTECTED`** means Stremio is running without complete controller evidence.
- **`INCOMPATIBLE`** means the bundled engine no longer matches the required structural fingerprints; the wrapper remains fail-closed.
- **`NOT INSTALLED`** means the wrapper or exact absolute override is missing or incorrect.
- **`ERROR`** means the verifier could not safely determine the state and must not be interpreted as zero upload.

---

## Handling Stremio Updates

After any Stremio or Flatpak update, run verification before streaming:

```bash
flatpak update com.stremio.Stremio
cd ~/stremio-mute
./scripts/verify.sh
```

If the result is `CONFIGURED`, launch Stremio normally. If the result is `INCOMPATIBLE`, run `./scripts/diagnose.sh` and submit a [compatibility report](https://github.com/LoneVertex/stremio-mute/issues). Do not bypass the fail-closed wrapper by manually writing a different `SERVER_PATH`.

---

## After Reboot

After restarting the desktop:

```bash
cd ~/stremio-mute
./scripts/verify.sh
```

`CONFIGURED` before launching Stremio is expected. Launch Stremio, start a stream, and run `./scripts/verify.sh` again. Require `RUNTIME VERIFIED` before treating runtime protection as confirmed.

---

## Rollback and Reinstall

To restore stock Stremio behavior:

```bash
cd ~/stremio-mute
./scripts/rollback.sh
./scripts/verify.sh
```

After rollback, `NOT INSTALLED` is expected. The script removes the project’s override, canonical wrapper, and legacy wrapper path without removing unrelated Stremio user data. To reinstall and regenerate the current user’s absolute path:

```bash
./scripts/install.sh
./scripts/verify.sh
```

---

## Architecture and Invariants

```text
Stremio Flatpak
      │
      ▼
absolute SERVER_PATH
      │
      ▼
server-wrapper.js
      │
      ▼
in-memory patched server.js
      │
      ▼
torrent engine + local player IPC
```

The controller enforces three invariants: zero rechoke upload slots, zero upload defaults, and immediate rejection of peer piece requests before disk reads. Its loopback metadata includes the controller version and executing-wrapper SHA256 so stale in-memory processes can be rejected. If any exact-one fingerprint check fails, the wrapper exits instead of running the unmodified server.
 For the protocol analysis and rejected network-layer alternatives, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Security and Limitations

Stremio Mute runs in user space with no `sudo`, root, firewall, systemd, or host network-interface changes. The status endpoint binds to loopback. The design is version-sensitive and depends on the internal JavaScript structure of the bundled Stremio server; upstream refactors can trigger fail-closed behavior and require a compatibility update.

See [SECURITY.md](SECURITY.md), [THREAT-MODEL.md](THREAT-MODEL.md), [TROUBLESHOOTING.md](TROUBLESHOOTING.md), and [COMPATIBILITY.md](COMPATIBILITY.md).

---

## License and Trademarks

This repository’s controller code and scripts are licensed under the [MIT License](LICENSE). Stremio is a trademark and product of Smart Code LTD. This project is an independent open-source tool and is not affiliated with or endorsed by Smart Code LTD.
