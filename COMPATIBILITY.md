# Compatibility Matrix & Update Model — Stremio Mute

**Controller Version:** `1.2.0`  
**Classification:** `PASS WITH VERSION-SENSITIVITY`  

---

## 1. Compatibility Matrix

To ensure technical precision, we distinguish between **Packaging Compatibility**, **Independently Tested Environments**, and **Untested Distributions**:

| Scope | Platform / Version | Status | Evidence / Notes |
|---|---|---|---|
| **Packaging** | Linux Flatpak (`com.stremio.Stremio` from Flathub) | **Supported** | Standard Flathub distribution mechanism |
| **Tested Environment** | Fedora 44 + KDE Plasma 6 + Linux 7.1 | **VERIFIED** | Stremio v1.2.0 (EngineFS v4.21.0 / `torrent-stream` #4d9eaff) |
| **Tested Stremio Engine** | Node.js CommonJS Webpack bundle (~6.5 MB) | **VERIFIED** | All 3 fingerprints matched exactly once |
| **Other Distributions** | Arch Linux, Ubuntu, Debian, openSUSE, etc. | **UNVERIFIED** | Expected to work via Flatpak sandbox; not independently tested |
| **Native Packaging** | `.deb`, `.rpm`, AUR, AppImage | **OUT OF SCOPE** | Requires Flatpak user environment override (`SERVER_PATH`) |

---

## 2. Structural Fingerprint Specification

The controller validates three structural fingerprints against `/app/libexec/stremio/server.js`. Each fingerprint MUST occur **exactly 1 time** in the target file:

### Fingerprint 1: Rechoke Allocation
- **Target Pattern:** `var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5`
- **Replacement:** `var rechokeIntervalId, rechokeSlots = 0 /* STREMIO MUTE ENFORCED */`
- **Expected Occurrences:** Exactly `1`

### Fingerprint 2: Constructor Option Defaults
- **Target Pattern:** `MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {`
- **Replacement:** `MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {\n                uploads: 0, /* STREMIO MUTE ENFORCED */`
- **Expected Occurrences:** Exactly `1`

### Fingerprint 3: Wire Request Handler Neutralization
- **Target Pattern:** `uploadPipe.push(engine.store.read, index, (function(err, buffer) {`
- **Replacement:** `return cb(new Error("Peer piece upload muted by policy")); uploadPipe.push(engine.store.read, index, (function(err, buffer) { /* STREMIO MUTE ENFORCED */`
- **Expected Occurrences:** Exactly `1`

---

## 3. Update Lifecycle: The Fail-Closed Guarantee

When Stremio is updated via `flatpak update com.stremio.Stremio`:

```text
Stremio Update Installed
          │
          ▼
User launches Stremio
          │
          ▼
server-wrapper.js reads /app/libexec/stremio/server.js
          │
          ├── [All 3 fingerprints match 1x?] ──► YES ──► Stremio starts with uploads muted ✅
          │
          └── NO ──► EMIT DIAGNOSTIC & PROCESS.EXIT(1) ❌
                     (Zero unmuted upload leakage)
```

If an update fails compatibility:
1. Stremio streaming server will abort and refuse to start unpatched.
2. Run `./scripts/verify.sh` to see which fingerprint mismatched.
3. Submit a [Compatibility Report](https://github.com/LoneVertex/stremio-mute/issues/new?template=compatibility_report.md) with `./scripts/diagnose.sh` output.
