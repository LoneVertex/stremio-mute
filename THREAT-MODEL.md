# Threat Model & Security Policy — Stremio Mute

**Project:** Stremio Mute (`LoneVertex/stremio-mute`)  
**Scope:** Node.js in-memory wrapper, absolute Flatpak user override, and loopback status telemetry

---

## 1. System Assets

| Asset | Description | Security Objective |
|---|---|---|
| **Upstream Bandwidth Quota** | User's upstream cellular/metered/broadband network quota. | Prevent unwanted BitTorrent piece seeding from exhausting data limits. |
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
- **Mitigation by Construction:** Invariant 3 neutralizes `wire.on("request")` by immediately invoking `cb(new Error("Peer piece upload muted by policy"))` before `uploadPipe.push(engine.store.read)` can access disk piece cache.

### Threat 3: Execution of Unprivileged / Malicious Code
- **Vector:** The wrapper script could be manipulated or executed with elevated permissions.
- **Risk:** Low.
- **Mitigation by Construction:** The wrapper runs entirely in user space inside the unprivileged Flatpak sandbox (`0644` file permissions). No `sudo`, setuid binaries, or kernel capabilities (`CAP_NET_ADMIN`) are requested or required.

### Threat 4: Local Port Exposure / IPC Interception

The status server is meaningful only after the wrapper has been loaded through the exact absolute `SERVER_PATH` configured for the current user. A missing, literal-tilde, stale, cross-user, or incorrect path is rejected by `verify.sh` and must not be treated as protected runtime evidence. v1.2.3 also stops a running Stremio process before deployment so an older in-memory wrapper cannot remain the accepted runtime after an update.
- **Vector:** External entities on LAN attempting to query controller status or stream endpoints.
- **Risk:** Low.
- **Mitigation by Construction:** The controller status endpoint (`/zero-upload-controller`) only binds to `127.0.0.1`. CORS headers restrict origin access to local loopback. The endpoint exposes only local policy and deployment identity fields, including `version` and `sourceSha256`; it does not expose stream names, user credentials, or remote telemetry.

---

## 3. Security Guarantees & Non-Goals

### Guaranteed by Construction:
- When the verified wrapper is active and all three fingerprints match exactly once, the enforced request path rejects peer piece uploads before the patched disk-read pipeline; this is an application-level guarantee, not a substitute for live packet measurement.
- Startup will fail closed if `server.js` structure differs from the verified fingerprints.
- Runtime verification requires the active endpoint version to match repository `VERSION` and `sourceSha256` to match the installed wrapper; installation stops running Stremio before deployment to avoid stale in-memory identity.
- The documented setup does not add third-party network services, addons, or external proxies.

### Non-Goals:
- The controller does not anonymize IP addresses or replace a VPN. (BitTorrent trackers still see Stremio's IP for peer discovery).
- The controller does not modify external tracker announce traffic (tracker announces transmit protocol metadata to join swarms).
- The controller does not claim zero total outbound packets; tracker/control, DNS, HTTPS, telemetry, and other background traffic may remain.
