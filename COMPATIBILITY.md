# Compatibility Matrix & Update Model — Stremio Zero-Upload Controller

**Controller Version:** `1.2.0`  
**Classification:** `PASS WITH VERSION-SENSITIVITY`

---

## 1. Verified Compatibility Matrix

| Stremio Flatpak Version | Engine Layer / Webpack | Target server.js Signature | Compatibility Status | Tested On |
|---|---|---|---|---|
| **`v1.2.0`** (Flathub) | EngineFS v4.21.0 / `torrent-stream` #4d9eaff | Node.js CommonJS bundle (~6.5 MB) | **VERIFIED** | Fedora 44 (Kernel 7.1), KDE Plasma |
| **`< v1.2.0`** (Legacy) | EngineFS < v4.20.0 | Variable | **UNKNOWN** | Not verified |
| **`> v1.2.0`** (Future) | TBD | TBD | **FAIL-CLOSED (Protected)** | Requires `verify.sh` check |

---

## 2. Structural Fingerprint Specification

The controller validates three structural fingerprints against `/app/libexec/stremio/server.js`. Each fingerprint MUST occur **exactly 1 time** in the target file:

### Fingerprint 1: Rechoke Allocation
- **Target Pattern:** `var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5`
- **Replacement:** `var rechokeIntervalId, rechokeSlots = 0 /* ZERO UPLOAD ENFORCED */`
- **Expected Occurrences:** Exactly `1`

### Fingerprint 2: Constructor Option Defaults
- **Target Pattern:** `MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {`
- **Replacement:** `MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {\n                uploads: 0, /* ZERO UPLOAD ENFORCED */`
- **Expected Occurrences:** Exactly `1`

### Fingerprint 3: Wire Request Handler Neutralization
- **Target Pattern:** `uploadPipe.push(engine.store.read, index, (function(err, buffer) {`
- **Replacement:** `return cb(new Error("Upload disabled by policy")); uploadPipe.push(engine.store.read, index, (function(err, buffer) { /* ZERO UPLOAD ENFORCED */`
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
          ├── [All 3 fingerprints match 1x?] ──► YES ──► Stremio starts in zero-upload mode ✅
          │
          └── NO ──► EMIT DIAGNOSTIC & PROCESS.EXIT(1) ❌
                     (Zero unsuppressed upload leakage)
```

If an update fails compatibility:
1. Stremio streaming server will abort and refuse to start unpatched.
2. Run `./scripts/verify.sh` to see which fingerprint mismatched.
3. Submit a [Compatibility Report](https://github.com/venom010101/stremio-zero-upload/issues/new?template=compatibility_report.md) with `./scripts/diagnose.sh` output.
