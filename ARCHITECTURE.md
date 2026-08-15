# Architecture & Technical Deep Dive — Stremio Mute

**Project:** Stremio Mute (`LoneVertex/stremio-mute`)  
**Target:** Stremio Linux Flatpak (`com.stremio.Stremio`)  
**Classification:** `PASS WITH VERSION-SENSITIVITY`  

---

## 1. Problem Definition & Root Cause

Stremio is an extensible media center that plays torrent streams sequentially to provide smooth video playback. Stremio packages an embedded Node.js streaming server (`server.js`) that uses an internal fork of [`torrent-stream`](https://github.com/mafintosh/torrent-stream) wrapped by Stremio's `EngineFS` layer (v4.21.0).

### Root Cause in `server.js`

In `server.js` (Webpack module ~814, lines 72445–72750), the BitTorrent engine constructor initializes upload slots as follows:

```javascript
var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5;
```

If `opts.uploads` is not explicitly set to `0` or `false`, `rechokeSlots` defaults to **5**.

In standard Stremio installations:
1. `EngineFS.getDefaults()` does not define an `uploads` option.
2. Stremio's HTTP settings API (`/settings`, `server-settings.json`) does not propagate an `uploads` value to `EngineFS`.
3. Consequently, every streaming engine allocates 5 upload slots.
4. When remote peers send BitTorrent `request` messages, `server.js` reads cached pieces from disk via `uploadPipe.push(engine.store.read, index, ...)` and transmits them to peers, consuming upstream bandwidth equal to or exceeding the media stream size.

---

## 2. Technical Evaluation of Alternative Architectures

During initial investigation, several system and network-level mechanisms were evaluated:

### 1. `nftables` / `conntrack` Directional Filtering (REJECTED)
- **Concept:** Filter egress traffic based on connection tracking state (`ct direction original accept; counter drop`).
- **Technical Inadequacy:** The BitTorrent protocol (BEP 3) is full-duplex and bidirectional over a single TCP socket. When Stremio initiates an outbound TCP connection to a peer (`ct direction original`), that connection carries both inbound download requests and outbound piece uploads. Therefore, accepting `ct direction original` permits 100% of peer piece uploads on outbound-initiated connections. Filtering by payload inspection at L4 is brittle and introduces kernel overhead.

### 2. UID / GID Filtering (REJECTED)
- **Concept:** Drop egress packets belonging to user UID `1000`.
- **Technical Inadequacy:** UID 1000 is shared by all user desktop processes (browsers, desktop shell, media players), causing collateral network blockage across the entire desktop session.

### 3. Network Namespaces & eBPF cgroups (REJECTED)
- **Concept:** Isolate Stremio in a dedicated network namespace with veth pair filtering.
- **Technical Inadequacy:** While network namespaces can isolate network traffic, implementing them for desktop Flatpak applications introduces substantial architectural drawbacks:
  - Requires elevated root/daemon privileges to manage namespace routing and veth bridges.
  - Requires intricate port-forwarding and proxy plumbing to route local media player traffic back to the host desktop player.
  - Adds brittle desktop integration overhead and higher maintenance burden compared to deterministic application-layer control.

---

## 3. The v1.2.4 In-Memory Controller Architecture

The **Stremio Mute** controller enforces policy at the application layer by modifying engine state directly in Node.js process memory. The launch path is:

```text
Stremio Flatpak
    → Flatpak user override with canonical absolute SERVER_PATH
    → $HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js
    → in-memory patched /app/libexec/stremio/server.js
    → torrent engine and local player IPC
```

The installer may use `$HOME` as shell notation when locating the current user’s home directory, but the persisted Flatpak environment value must be the expanded absolute app-owned path. The former `$HOME/.stremio-server/server-wrapper.js` location is a legacy host-only deployment and is removed. A literal tilde is not expanded by Flatpak or the Node.js process and is therefore invalid. The installer and verifier prove that the canonical wrapper is readable inside the sandbox. This distinction is mandatory for install, verify, rollback, reboot, update, and reinstall behavior.

```text
                               +--------------------------------------------+
                               |              Stremio GUI (Rust)            |
                               +--------------------------------------------+
                                                     |
                                                     | (Spawns Node using SERVER_PATH)
                                                     v
                               +--------------------------------------------+
                               |        src/server-wrapper.js (v1.2.4)      |
                               +--------------------------------------------+
                                                     |
                     +-------------------------------+-------------------------------+
                     |                               |                               |
                     v                               v                               v
         [Invariant 1: Rechoke]           [Invariant 2: Defaults]          [Invariant 3: Wire Request]
          `rechokeSlots = 0`             `defaults.uploads = 0`            `return cb(policy_error)`
                     |                               |                               |
                     +-------------------------------+-------------------------------+
                                                     |
                                                     v
                               +--------------------------------------------+
                               |         server.js (Node.js Engine)         |
                               +--------------------------------------------+
                                      |                              |
                                      v                              v
                         [Local Player HTTP Endpoint]     [BitTorrent Peer Wires]
                           http://127.0.0.1:11470         - Remote unchokes Stremio -> DOWNLOAD OK
                                                          - Stremio chokes remote -> ZERO UPLOAD
```

### The Three Enforced Invariants

The wrapper is loaded only through the exact canonical absolute `SERVER_PATH` configured for the current user. `verify.sh` requires that persisted value to match the app-owned `$HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js` location and proves that the path is readable inside the sandbox; missing, literal-tilde, legacy-host, stale, cross-user, and incorrect paths are rejected.

#### Invariant 1: `rechokeSlots = 0` (Local Choking State)
- **Mechanism:** In the periodic rechoke timer loop:
  ```javascript
  for (var i = 0, unchokeInterested = 0; i < peers.length && unchokeInterested < rechokeSlots; ++i)
  ```
  Because `rechokeSlots === 0`, `unchokeInterested < 0` is false on index 0. Zero peers are ever unchoked. All peer wires maintain `isChoked = true` and `wire.amChoking = true`.
- **Wire Effect:** In `Wire.prototype._onrequest`, incoming peer requests check `if (!this.amChoking)`. Because `amChoking === true`, all incoming peer requests are discarded at the protocol wire parser before reaching the application layer.

#### Invariant 2: `EngineFS.getDefaults().uploads = 0`
- **Mechanism:** `EngineFS.getDefaults()` returns `defaults = { uploads: 0, ... }`. Any new engine instance receives `options.uploads = 0` by default.

#### Invariant 3: Request Handler Neutralization
- **Mechanism:** In `wire.on("request", ...)`, the handler is patched:
  ```javascript
  return cb(new Error("Peer piece upload muted by policy"));
  uploadPipe.push(engine.store.read, index, ...);
  ```
- **Defense in Depth:** Even if a peer bypassed wire choking, the handler returns an immediate error before `engine.store.read` can read disk pieces or call `self.piece()`.

---

## 4. Protocol Asymmetry: Why Download Still Works

Under the BitTorrent protocol specification (BEP 3), upload and download states are entirely decoupled:

| Wire Property | Meaning | Controlled By | State in Stremio Mute |
|---|---|---|---|
| `wire.amChoking` | Stremio chokes remote peer (No uploads to peer) | Stremio Engine | **`true` (Permanently Choked)** |
| `wire.peerChoking` | Remote peer chokes Stremio | Remote Peer | **`false` (When peer unchokes us)** |
| `wire.amInterested` | Stremio wants pieces from remote peer | Stremio Engine | **`true` (When pieces needed)** |
| `wire.peerInterested` | Remote peer wants pieces from Stremio | Remote Peer | Ignored (Cannot request) |

The policy target is zero observed BitTorrent peer-piece upload from the protected engine, not zero total outbound packets. Tracker/control, DNS, HTTPS, telemetry, and other background traffic are outside that guarantee and may continue.

When Stremio connects to seeders:
1. Stremio sends `interested` and `choke` to the remote peer.
2. The remote peer unchokes Stremio (`peerChoking = false`).
3. Stremio sends standard `request` messages for video blocks.
4. The remote peer replies with `piece` blocks.
5. Stremio's `wire._onpiece` receives the block, accumulates `downloaded` bytes, and writes the chunk to local disk cache.
6. The video file stream serves `127.0.0.1:11470` to the local player.

---

## 5. Security & Failure-Mode Design

1. **No Silent Fallback:** The wrapper strictly forbids falling back to stock `server.js` if an error occurs.
2. **Exact-1 Fingerprint Matching:** Every patch pattern must match **exactly 1 occurrence** in `server.js`.
3. **Fail-Closed Mechanics:** If an upstream update modifies `server.js` code structure, the process terminates immediately (`process.exit(1)`) and outputs diagnostics.
4. **Loopback Status Telemetry:** Exposes `http://127.0.0.1:11470/zero-upload-controller` exclusively on `127.0.0.1` for health checks.
5. **Deployment Identity:** Reports the controller release version and wrapper SHA256; installation stops a running Stremio process before deployment so endpoint metadata cannot remain from an older in-memory wrapper.
6. **Runtime Verification:** `verify.sh` accepts `RUNTIME VERIFIED` only when the active endpoint version matches the repository `VERSION`, its `sourceSha256` matches the canonical installed wrapper, heartbeat is healthy, the canonical path is sandbox-visible, no legacy wrapper competes, and the required upload-suppression invariants are present.
