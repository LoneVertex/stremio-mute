# Compatibility Matrix and Update Model — Stremio Mute v1.2.3

**Controller version:** `1.2.3`
**Classification:** `PASS WITH VERSION-SENSITIVITY`

The **controller version** identifies this repository’s scripts and wrapper. The **verified Stremio version** identifies an upstream Stremio engine whose bundled `server.js` matched the controller’s structural fingerprints. These are separate versions and must not be conflated.

---

## 1. Compatibility Matrix

| Scope | Platform or version | Status | Evidence or notes |
|---|---|---|---|
| **Packaging** | Linux Flatpak `com.stremio.Stremio` | **SUPPORTED** | Standard Flatpak user-override installation model |
| **Controller** | Stremio Mute v1.2.3 | **CURRENT** | Absolute-path installer, exact verifier, fail-closed wrapper |
| **Verified target** | Stremio v1.2.0 / EngineFS v4.21.0 / `torrent-stream` reference `#4d9eaff` | **VERIFIED** | Three structural fingerprints matched exactly once in the tested engine bundle |
| **Verified environment** | Fedora 44 + KDE Plasma 6 + Linux 7.1 | **VERIFIED** | Environment associated with the verified target evidence |
| **Other distributions** | Arch Linux, Ubuntu, Debian, openSUSE | **UNVERIFIED** | Expected to work through Flatpak but not independently tested by this project |
| **Native packages** | `.deb`, `.rpm`, AUR, AppImage | **OUT OF SCOPE** | The controller is designed for the Flatpak user environment override |
| **Separate service application** | `com.stremio.Service` | **UNVERIFIED / NOT REQUIRED BY DOCUMENTED SETUP** | Current instructions target `com.stremio.Stremio`; no separate service is installed or configured by this project |

`VERIFIED` refers only to the documented evidence for the listed target and environment. It does not mean that every Linux distribution or every future Stremio release is verified.

---

## 2. Absolute `SERVER_PATH` Persistence

The installer stages the wrapper at `$HOME/.stremio-server/server-wrapper.js` and stores the expanded absolute path in the Flatpak user override. For a user whose home directory is `/home/current-user`, the persisted value must be:

```text
SERVER_PATH=/home/current-user/.stremio-server/server-wrapper.js
```

The shell expression `$HOME/.stremio-server/server-wrapper.js` is not itself the stored value. The literal `SERVER_PATH=~/.stremio-server/server-wrapper.js` is invalid because the Flatpak runtime does not expand the tilde. The verifier rejects missing, literal-tilde, stale, wrong, cross-user, and cross-project paths.

Inspect the actual value with:

```bash
flatpak override --user --show com.stremio.Stremio
```

---

## 3. Structural Fingerprint Specification

The controller validates three structural fingerprints against `/app/libexec/stremio/server.js`. Each fingerprint must occur exactly once in the target file.

### Fingerprint 1: Rechoke Allocation

- **Target pattern:** `var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5`
- **Replacement:** `var rechokeIntervalId, rechokeSlots = 0 /* STREMIO MUTE ENFORCED */`
- **Expected occurrences:** Exactly `1`

### Fingerprint 2: Constructor Option Defaults

- **Target pattern:** `MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {`
- **Replacement:** Adds `uploads: 0` to the defaults object.
- **Expected occurrences:** Exactly `1`

### Fingerprint 3: Wire Request Handler Neutralization

- **Target pattern:** `uploadPipe.push(engine.store.read, index, (function(err, buffer) {`
- **Replacement:** Returns a policy error before the disk-piece read pipeline.
- **Expected occurrences:** Exactly `1`

---

## 4. Verifier States

The verifier distinguishes these states:

| State | Meaning |
|---|---|
| `CONFIGURED` | The wrapper, exact absolute override, source bytes, and compatibility checks are valid while Stremio is idle |
| `RUNTIME VERIFIED` | Stremio is running and controller plus heartbeat evidence confirms protected execution |
| `NOT PROTECTED` | Stremio is running without complete controller evidence |
| `INCOMPATIBLE` | One or more structural fingerprints do not match; the wrapper remains fail-closed |
| `NOT INSTALLED` | The wrapper or exact absolute override is missing or incorrect |
| `ERROR` | The verifier could not safely determine the installation state |

`CONFIGURED` before launching Stremio is expected. `RUNTIME VERIFIED` requires a running Stremio server.

---

## 5. Update Lifecycle and Fail-Closed Guarantee

When Stremio is updated through Flatpak:

```text
Stremio update installed
          │
          ▼
User runs verify.sh before streaming
          │
          ▼
server-wrapper.js reads /app/libexec/stremio/server.js
          │
          ├── All 3 fingerprints match exactly once? ── YES ──► Start protected engine
          │
          └── NO ──► Emit diagnostics and exit(1)
                       No unverified fallback
```

After any update, run:

```bash
flatpak update com.stremio.Stremio
cd ~/stremio-mute
./scripts/verify.sh
```

If compatibility fails, run `./scripts/diagnose.sh` and submit a [compatibility report](https://github.com/LoneVertex/stremio-mute/issues/new?template=compatibility_report.md). The controller intentionally refuses to run unverified internal code.

---

## 6. Evidence Boundaries

The controller’s structural compatibility can be tested using the repository fixtures and an installed Flatpak engine. Live KDE launch, real stream playback, peer counts, packet-level upload measurement, and post-reboot persistence require a suitable desktop environment and are not implied by static repository tests. Do not broaden the `VERIFIED` label beyond the environment and target version listed in the matrix.

At runtime, the controller endpoint reports both the v1.2.3 controller version and the SHA256 of the executing wrapper source. Verification requires the endpoint version to match the repository `VERSION` and the reported source hash to match the installed wrapper bytes. A running process from an older wrapper is therefore not accepted as `RUNTIME VERIFIED` after deployment.
