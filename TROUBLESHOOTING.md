# Troubleshooting Guide — Stremio Mute v1.2.5

This guide covers common diagnostic workflows, verifier states, update failures, and lifecycle problems.

> **Safety rule:** Never interpret missing telemetry or `ERROR` as proof that uploads are muted. The controller is fail-closed and version-sensitive.

---

## 1. Start with the Verifier

From the repository checkout, run:

```bash
cd ~/stremio-mute
./scripts/verify.sh
```

For a sanitized diagnostic snapshot, run:

```bash
./scripts/diagnose.sh
```

Inspect the persisted Flatpak override with:

```bash
flatpak override --user --show com.stremio.Stremio
```

When Stremio Mute is installed, the `SERVER_PATH` value must be the canonical absolute app-owned path such as `/home/current-user/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js`. After rollback, the required stock value is `/app/libexec/stremio/server.js`. The former host-only `$HOME/.stremio-server/server-wrapper.js` path is legacy. The literal `SERVER_PATH=~/.stremio-server/server-wrapper.js` is **OLD / INVALID / HISTORICAL** and must not be written manually.

---

## 2. Interpreting Status Output

### `STATUS: CONFIGURED`

Static configuration is valid: the canonical app-owned absolute `SERVER_PATH` is stored, the wrapper matches the repository source, the canonical path is readable inside the sandbox, project-managed legacy copies are absent, and the structural fingerprints match. Stremio is currently idle.

**Action:** Launch Stremio, start a stream, and run `./scripts/verify.sh` again.

### `STATUS: RUNTIME VERIFIED`

Stremio is running, the loopback controller endpoint confirms the policy, the heartbeat is healthy, the endpoint version matches the repository `VERSION`, and the endpoint source SHA256 matches the installed wrapper bytes.

**Action:** No action is required; runtime protection is active.

If the endpoint reports an older controller version or a different source SHA256, the process is stale or another wrapper copy is serving the endpoint. Stop Stremio, run `./scripts/install.sh` so the installer terminates any running process before staging, relaunch Stremio, and require `RUNTIME VERIFIED` again.

### `STATUS: NOT PROTECTED`

Stremio’s server is running, but complete controller evidence is missing. Possible causes include a cleared override, a launch path that bypassed the user override, or a stock server process.

**Action:** Stop Stremio, inspect `flatpak override --user --show com.stremio.Stremio`, rerun the installer, relaunch Stremio, and verify again.

### `STATUS: INCOMPATIBLE`

The installed Stremio `server.js` no longer matches one or more exact structural fingerprints.

**Behavior:** The controller fails closed and refuses to start unverified code.

**Action:** Run `./scripts/diagnose.sh`, submit a [compatibility issue](https://github.com/LoneVertex/stremio-mute/issues/new?template=compatibility_report.md), and do not bypass the wrapper.

### `STATUS: NOT INSTALLED`

The canonical app-owned wrapper, exact absolute `SERVER_PATH`, or sandbox visibility proof is missing or incorrect. This includes a literal tilde, the old host-only path, a stale path, another user’s path, or a path from another project.

**Action:** Run `./scripts/install.sh` and verify again. After rollback, `STATUS: NOT INSTALLED` is expected, but the effective stock `SERVER_PATH` must still be present and Stremio must remain launchable.

### Stock Stremio after rollback

A clean rollback reports `STATUS: NOT INSTALLED` for Mute, but stock Stremio must still receive `SERVER_PATH=/app/libexec/stremio/server.js`. Check the effective value inside the sandbox:

```bash
flatpak run --command=node com.stremio.Stremio -e 'process.stdout.write(process.env.SERVER_PATH || "")'
```

If the command prints nothing or Stremio reports `Failed to read SERVER_PATH env: NotPresent`, restore the required stock value without deleting additional data:

```bash
flatpak override --user --env=SERVER_PATH=/app/libexec/stremio/server.js com.stremio.Stremio
flatpak override --user --show com.stremio.Stremio
```

Then launch stock Stremio again. Do not run an older rollback script that uses `--unset-env=SERVER_PATH`.

### `STATUS: ERROR`

The verifier could not safely determine the installation state because a prerequisite, compatibility check, or runtime query failed.

**Action:** Run `./scripts/diagnose.sh` and resolve the reported condition. Do not interpret `ERROR` as protected runtime behavior.

---

## 3. Stremio Starts but Reports “Streaming Server Unavailable”

Use this sequence when the Stremio application opens but reports that its streaming server is unavailable:

1. Inspect the Flatpak user override:

   ```bash
   flatpak override --user --show com.stremio.Stremio
   ```

   Confirm that `SERVER_PATH` is the canonical absolute app-owned path to the current user’s wrapper, such as `/home/current-user/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js`.

2. Reject the historical broken form. Do not configure:

   ```text
   SERVER_PATH=~/.stremio-server/server-wrapper.js
   ```

3. Run the verifier:

   ```bash
   cd ~/stremio-mute
   ./scripts/verify.sh
   ```

4. Inspect the heartbeat endpoint while Stremio is running:

   ```bash
   curl -fsS http://127.0.0.1:11470/heartbeat
   ```

5. Inspect the controller endpoint:

   ```bash
   curl -fsS http://127.0.0.1:11470/zero-upload-controller
   ```

6. If the endpoint checks fail, generate diagnostics:

   ```bash
   ./scripts/diagnose.sh
   ```

   If the verifier reports `INCOMPATIBLE`, do not stream until the upstream compatibility is reviewed. If it reports `NOT INSTALLED`, rerun `./scripts/install.sh`.

The endpoint response is implementation evidence only; missing, malformed, version-mismatched, or source-hash-mismatched responses must not be treated as `RUNTIME VERIFIED`.

---

## 4. Literal Tilde or Incorrect `SERVER_PATH`

**Cause:** An old installation or manual override stored the **OLD / INVALID / HISTORICAL** tilde form, persisted the legacy host-only `$HOME/.stremio-server/server-wrapper.js` path, pointed to another absolute location, or retained a stale path after a user or checkout change.

**Diagnosis:**

```bash
flatpak override --user --show com.stremio.Stremio
```

**Fix:** Reinstall from the current checkout:

```bash
cd ~/stremio-mute
git checkout v1.2.5
./scripts/install.sh
./scripts/verify.sh
```

The installer computes and persists the canonical app-owned absolute path dynamically, removes the legacy host wrapper, and proves sandbox visibility. Do not manually write a tilde value or restore the old host-only path.

---

## 5. After Reboot or Stremio Restart

After reboot, a stopped Stremio server should produce `CONFIGURED`:

```bash
cd ~/stremio-mute
./scripts/verify.sh
```

Launch Stremio, start a stream, and verify again:

```bash
flatpak run com.stremio.Stremio
./scripts/verify.sh
```

Require `RUNTIME VERIFIED` before claiming active runtime protection.

---

## 6. After a Stremio or Flatpak Update

Always verify before streaming:

```bash
flatpak update com.stremio.Stremio
cd ~/stremio-mute
./scripts/verify.sh
```

If the result is `INCOMPATIBLE`, run `./scripts/diagnose.sh` and submit the compatibility report. The controller intentionally exits instead of silently falling back to stock `server.js`.

---

## 7. Rollback and Reinstall

Restore the stock server path, remove the project configuration, and verify removal:

```bash
cd ~/stremio-mute
./scripts/rollback.sh
./scripts/verify.sh
```

The expected post-rollback state is `NOT INSTALLED`. Rollback first verifies and restores `SERVER_PATH=/app/libexec/stremio/server.js` inside the Flatpak, then removes the canonical app-owned wrapper and legacy host wrapper without removing unrelated Stremio user data. If stock-path restoration cannot be verified, rollback stops before deleting the existing wrapper deployment.

Reinstall and verify again:

```bash
./scripts/install.sh
./scripts/verify.sh
```

Reinstall regenerates the current user’s canonical app-owned absolute `SERVER_PATH`, proves sandbox visibility, removes the legacy host wrapper, and is safe to repeat.

---

## 8. Common Installer Errors

### `Pre-flight compatibility validation failed`

The installed Stremio bundle does not match the required fingerprints. The installer aborts before staging files or applying the override. Run `./scripts/diagnose.sh` and submit a compatibility report.

### `Flatpak CLI not found`

Install Flatpak through your distribution, then rerun `flatpak --version` and the installer.

### `com.stremio.Stremio is not installed`

Install the Stremio Flatpak:

```bash
flatpak install flathub com.stremio.Stremio
```

Then rerun `./scripts/install.sh`.

### Streaming server exits on launch

This may be fail-closed compatibility protection. Run `./scripts/verify.sh` and `./scripts/diagnose.sh`; do not replace the wrapper with stock `server.js` or manually alter `SERVER_PATH`.
