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

### `STATUS: CONFIGURED`
- **Meaning:** Static configuration is valid, the exact absolute `SERVER_PATH` is stored, and all structural code fingerprints match. Stremio is currently idle.
- **Action:** Launch Stremio and start playing a stream. Run `./scripts/verify.sh` again to confirm runtime enforcement.

### `STATUS: RUNTIME VERIFIED`
- **Meaning:** Stremio is running, the active loopback controller endpoint on `127.0.0.1:11470/zero-upload-controller` confirms the policy, and the heartbeat is healthy.
- **Action:** No action is required; runtime protection is active.

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
- **Meaning:** The controller wrapper or exact absolute `SERVER_PATH` configuration is missing or incorrect. This includes a literal `~` path, a stale path, a path for another user, or a path pointing to another project.
- **Fix:** Inspect `flatpak override --user --show com.stremio.Stremio`, then run `./scripts/install.sh`.

### `STATUS: ERROR`
- **Meaning:** The verifier could not safely determine the installation state, for example because a required prerequisite or compatibility check could not be executed.
- **Fix:** Run `./scripts/diagnose.sh` and resolve the reported prerequisite or runtime issue. Do not interpret this state as zero upload.

---

## 3. Common Error Scenarios

### Error: `Pre-flight compatibility validation failed` during `install.sh`
- **Cause:** The installer detected that Stremio's bundled `server.js` does not match the required fingerprints.
- **Protection:** The installer aborted **before** staging files or applying overrides, keeping your installation safe and unmodified.

### Error: `SERVER_PATH` contains a literal tilde or wrong path
- **Cause:** The Flatpak override was stored as `SERVER_PATH=~/.stremio-server/server-wrapper.js`, points to another absolute location, or is stale after reinstall.
- **Diagnosis:** Run `flatpak override --user --show com.stremio.Stremio`. The value must be the current user’s absolute path, such as `/home/current-user/.stremio-server/server-wrapper.js`.
- **Fix:** Run `./scripts/install.sh`. Do not manually store a literal tilde; the installer computes the absolute path dynamically.

### Error: Stremio Streaming Server Exits on Launch
- **Cause:** Fail-closed protection triggered due to code mismatch.
- **Diagnosis:** Run `flatpak run com.stremio.Stremio` in a terminal to view error logs.
