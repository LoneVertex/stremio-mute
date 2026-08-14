# Troubleshooting Guide — Stremio Zero-Upload Controller

This guide covers common issues, diagnostic steps, and resolutions.

---

## 1. Quick Diagnosis

Always start by running:
```bash
./scripts/verify.sh
```
and
```bash
./scripts/diagnose.sh
```

---

## 2. Common Issues & Solutions

### Issue: `STATUS: NOT PROTECTED` in `verify.sh`
- **Cause 1:** Stremio Flatpak override is missing.
  - **Fix:** Run `./scripts/install.sh` to reinstall the override.
- **Cause 2:** Stremio was updated and internal code structure changed.
  - **Fix:** Check `verify.sh` output under section 3 (Compatibility Fingerprints). If mismatch is reported, see [COMPATIBILITY.md](COMPATIBILITY.md).

### Issue: Stremio Fails to Launch or Exits Immediately
- **Cause:** Compatibility mismatch triggering the fail-closed protection.
- **Verification:** Run `flatpak run com.stremio.Stremio` from a terminal and look for `[Upload-Control] FATAL COMPATIBILITY ERROR`.
- **Fix:** The controller safely refused to run because `server.js` was modified. Run `./scripts/rollback.sh` to revert to stock Stremio while awaiting a controller update.

### Issue: Video Plays but `verify.sh` Reports `STATUS: CONFIGURED`
- **Cause:** Stremio GUI is open, but the streaming engine is idle or using a cached file without active streaming server sockets.
- **Verification:** Start playing any stream, then run `./scripts/verify.sh` again. It should report `STATUS: RUNTIME VERIFIED (ZERO UPLOAD ENFORCED)`.

### Issue: `Permission denied` on Scripts
- **Fix:** Ensure execution permissions are set:
  ```bash
  chmod +x scripts/*.sh
  ```
