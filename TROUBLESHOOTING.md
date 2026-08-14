# Troubleshooting Guide — Stremio Mute

This guide covers common diagnostic workflows, error states, and resolutions.

---

## 1. Quick Diagnosis

Always begin troubleshooting by running:
```bash
./scripts/verify.sh
```
and generating a diagnostic snapshot:
```bash
./scripts/diagnose.sh
```

---

## 2. Interpreting Status Output

### `STATUS: CONFIGURED (STATIC VALIDATION PASSED)`
- **Meaning:** Stremio Mute is correctly installed and all structural code fingerprints match your installed Stremio version. Stremio is currently idle.
- **Action:** Launch Stremio and start playing any video stream. Run `./scripts/verify.sh` again to confirm runtime enforcement.

### `STATUS: RUNTIME VERIFIED (UPLOADS MUTED)`
- **Meaning:** Stremio is running, the streaming engine is active, and the authoritative loopback controller endpoint on `127.0.0.1:11470/zero-upload-controller` confirmed that upload suppression invariants are active.
- **Action:** No action required. Protection is active.

### `STATUS: NOT PROTECTED`
- **Meaning:** Stremio's streaming server is running on `127.0.0.1:11470`, but the controller status endpoint is not responding, indicating stock unprotected Stremio is executing.
- **Possible Causes:**
  - Flatpak environment override `SERVER_PATH` was cleared or not applied.
  - Stremio was launched in a manner that bypassed user Flatpak overrides.
- **Fix:** Re-run the installer:
  ```bash
  ./scripts/install.sh
  ```

### `STATUS: INCOMPATIBLE`
- **Meaning:** Stremio was updated, and the minified structure of `/app/libexec/stremio/server.js` no longer matches the expected code fingerprints.
- **Behavior:** The controller **fails closed** (`process.exit(1)`), preventing unmuted uploads.
- **Fix:** Run `./scripts/diagnose.sh` to capture the fingerprint match counts and submit a [Compatibility Issue](https://github.com/LoneVertex/stremio-mute/issues). To use stock Stremio in the interim, run `./scripts/rollback.sh`.

### `STATUS: NOT INSTALLED`
- **Meaning:** The controller wrapper file or Flatpak user override is missing.
- **Fix:** Run `./scripts/install.sh`.

---

## 3. Common Error Scenarios

### Error: `Pre-flight compatibility validation failed` during `install.sh`
- **Cause:** The installer detected that Stremio's bundled `server.js` does not match the required fingerprints.
- **Protection:** The installer aborted **before** staging files or applying overrides, keeping your installation safe and unmodified.

### Error: Stremio Streaming Server Exits on Launch
- **Cause:** Fail-closed protection triggered due to code mismatch.
- **Diagnosis:** Run `flatpak run com.stremio.Stremio` in a terminal to view error logs.
