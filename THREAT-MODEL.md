# Threat Model & Security Policy — Stremio Zero-Upload Controller

**Document Version:** 1.0.0  
**Scope:** `stremio-zero-upload` (Node.js in-memory wrapper & Flatpak override)  

---

## 1. System Assets

| Asset | Description | Security Objective |
|---|---|---|
| **ISP Bandwidth Quota** | Upstream cellular/metered/broadband network quota. | Prevent unwanted BitTorrent piece seeding from exhausting data limits. |
| **Local Stremio Playback** | Media streaming performance and player responsiveness. | Ensure video chunks download and stream without degradation. |
| **Local IPC Integrity** | HTTP communication on `127.0.0.1:11470`. | Ensure loopback communication between Stremio GUI and engine is reliable and secure. |
| **System Security & Isolation** | Host OS security, user privacy, and Flatpak sandbox isolation. | Prevent privilege escalation, path traversal, or credential leakage. |

---

## 2. Threat Analysis & Mitigations

### Threat 1: Upstream Stremio Update Silently Re-Enables Upload
- **Vector:** An upstream Flatpak package update changes `server.js` minified variable names or AST structure, causing simple replacements to fail.
- **Risk:** High (Silent data leakage).
- **Mitigation by Construction:** The controller uses **exact-1 structural compatibility fingerprinting**. If any pattern fails to match exactly once, the wrapper emits a diagnostic and executes `process.exit(1)` (**FAIL-CLOSED**). It strictly refuses to launch unpatched Stremio.

### Threat 2: Bypass of BitTorrent Choking Logic by Malicious Peers
- **Vector:** A rogue BitTorrent peer sends `request` messages despite being choked (`wire.amChoking = true`).
- **Risk:** Medium (Potential piece upload).
- **Mitigation by Construction:** Invariant 3 neutralizes `wire.on("request")` by immediately invoking `cb(new Error("Upload disabled by policy"))` before `uploadPipe.push(engine.store.read)` can access disk piece cache.

### Threat 3: Execution of Unprivileged / Malicious Code
- **Vector:** The wrapper script could be manipulated or executed with elevated permissions.
- **Risk:** Low.
- **Mitigation by Construction:** The wrapper runs entirely in user space inside the unprivileged Flatpak sandbox (`0644` file permissions). No `sudo`, setuid binaries, or kernel capabilities (`CAP_NET_ADMIN`) are requested or required.

### Threat 4: Local Port Exposure / IPC Interception
- **Vector:** External entities on LAN attempting to query controller status or stream endpoints.
- **Risk:** Low.
- **Mitigation by Construction:** The controller status endpoint (`/zero-upload-controller`) only binds to `127.0.0.1`. CORS headers restrict origin access. No sensitive metadata (stream names, user credentials, hashes) is exposed in telemetry.

---

## 3. Security Guarantees & Non-Goals

### Guaranteed by Construction:
- Zero media pieces will be read from disk or transmitted across TCP peer wires when the controller is active.
- Startup will fail closed if `server.js` structure differs from verified fingerprints.
- No third-party network services, addons, or external proxies are contacted.

### Non-Goals:
- The controller does not anonymize IP addresses or replace a VPN. (BitTorrent trackers still see Stremio's IP for peer discovery).
- The controller does not modify external tracker announce traffic (tracker announces transmit ~200 bytes of protocol metadata to join swarms).
