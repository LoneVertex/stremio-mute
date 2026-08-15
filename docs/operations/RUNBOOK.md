# Operational Runbook — Stremio Mute v1.2.4

**Audience:** System administrators, desktop Linux users, and power users
**System target:** Linux Flatpak Stremio `com.stremio.Stremio`
**Compatibility model:** Version-sensitive and fail-closed

This runbook is the operational source of truth for the v1.2.4 documentation.
 The controller version and the independently verified Stremio engine version are separate; see [COMPATIBILITY.md](../../COMPATIBILITY.md).

---

## 1. Day-One Installation

### 1.1 Clone the published checkout

```bash
git clone https://github.com/LoneVertex/stremio-mute.git
cd stremio-mute
git checkout v1.2.4
```

### 1.2 Confirm prerequisites

```bash
flatpak --version
git --version
flatpak info com.stremio.Stremio
```

The installer requires Flatpak and an installed `com.stremio.Stremio` application. Host Node.js is optional for installation; when present, it provides an additional wrapper syntax check.

### 1.3 Install and verify

```bash
./scripts/install.sh
./scripts/verify.sh
```

The installer performs compatibility pre-flight before staging the wrapper or changing the Flatpak override. It stops any running Stremio process to prevent stale in-memory controller metadata, stages the wrapper at `$HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js`, removes the legacy host wrapper at `$HOME/.stremio-server/server-wrapper.js`, computes the current user’s canonical absolute app-owned path, proves sandbox visibility, persists that path through `flatpak override --user`, verifies the stored value, and runs the verifier.

When Stremio is stopped, the expected state is:

```text
STATUS: CONFIGURED
```

`CONFIGURED` confirms static configuration only. It does not claim that the Stremio server is running.

---

## 2. Absolute `SERVER_PATH` Rule

Use `$HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js` in shell commands as shorthand only. The persisted Flatpak environment value must be the expanded absolute app-owned path. For example:

```text
SERVER_PATH=/home/current-user/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js
```

The former host-only `$HOME/.stremio-server/server-wrapper.js` location is legacy. This is **OLD / INVALID / HISTORICAL** and must not be configured:

```text
SERVER_PATH=~/.stremio-server/server-wrapper.js
```

The Flatpak environment and Stremio’s Node.js process do not expand a literal tilde in this value. Inspect the actual stored configuration with:

```bash
flatpak override --user --show com.stremio.Stremio
```

The `SERVER_PATH` shown there must exactly match the current user’s absolute app-owned `$HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js` path, and the verifier must prove that the wrapper is readable inside the sandbox.

---

## 3. Launch and Runtime Verification

Launch Stremio from the desktop application menu or from a terminal:

```bash
flatpak run com.stremio.Stremio
```

Start a stream, then run:

```bash
./scripts/verify.sh
```

The expected protected running state is:

```text
STATUS: RUNTIME VERIFIED
```

This state requires Stremio to be running, the canonical app-owned path to be sandbox-visible, no legacy wrapper to compete, the controller endpoint and heartbeat to respond, the controller to be active, the endpoint version to match the repository `VERSION`, the endpoint `sourceSha256` to match the canonical installed wrapper bytes, and the upload-suppression invariants to be present. The status endpoint exposes `project`, `version`, `sourceSha256`, `active`, `muted`, `policy`, and nested invariant fields for `uploads`, `rechokeSlots`, and `wireRequestBlocked`. If Stremio is stopped, `CONFIGURED` is correct. Do not treat `ERROR`, `NOT PROTECTED`, stale metadata, or missing telemetry as proof of zero peer-piece upload.

### 3.1 Restarting Stremio

After closing and reopening Stremio, the new process loads the current wrapper bytes. Launch it normally, start a stream, and rerun the verifier:

```bash
flatpak run com.stremio.Stremio
cd ~/stremio-mute
./scripts/verify.sh
```

Require `RUNTIME VERIFIED` before treating the active runtime as confirmed.

---

## 4. Post-Reboot Procedure

After restarting Fedora or another supported Linux desktop:

```bash
cd ~/stremio-mute
./scripts/verify.sh
```

Before Stremio is launched, `CONFIGURED` is expected. Launch Stremio and start a stream:

```bash
flatpak run com.stremio.Stremio
./scripts/verify.sh
```

The expected result is `RUNTIME VERIFIED`. If it is not, inspect the exact override and diagnostics before streaming. A version or source-hash mismatch indicates stale in-memory state or another wrapper copy; rerun the supported installer lifecycle rather than editing arbitrary runtime state.

---

## 5. Stremio and Flatpak Updates

Always verify after an update and before streaming:

```bash
flatpak update com.stremio.Stremio
cd ~/stremio-mute
./scripts/verify.sh
```

If the result is `CONFIGURED`, launch Stremio and verify again at runtime. If it is `INCOMPATIBLE`, the bundled `server.js` no longer matches the exact structural fingerprints. The wrapper must fail closed rather than run unverified code. Collect diagnostics:

```bash
./scripts/diagnose.sh
```

Submit the report through the [compatibility issue template](https://github.com/LoneVertex/stremio-mute/issues/new?template=compatibility_report.md). Do not manually replace the absolute `SERVER_PATH` with a literal tilde or bypass the wrapper.

---

## 6. Troubleshooting and Diagnostics

Start with the verifier:

```bash
cd ~/stremio-mute
./scripts/verify.sh
```

Inspect the persisted override:

```bash
flatpak override --user --show com.stremio.Stremio
```

Generate a sanitized diagnostic snapshot:

```bash
./scripts/diagnose.sh
```

For a running server, optional loopback checks are:

```bash
curl -fsS http://127.0.0.1:11470/heartbeat
curl -fsS http://127.0.0.1:11470/zero-upload-controller
```

If either endpoint is unavailable, reports an older controller version, or reports a source hash different from the installed wrapper, do not claim runtime protection. Stop Stremio, rerun the installer, relaunch it, and consult [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md) for state-specific handling.

---

## 7. Rollback and Removal Verification

To restore stock Stremio behavior:

```bash
cd ~/stremio-mute
./scripts/rollback.sh
./scripts/verify.sh
```

A successful removal should result in `STATUS: NOT INSTALLED`. Rollback removes the project’s Flatpak user override, the canonical app-owned `$HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js` wrapper, and the legacy host `$HOME/.stremio-server/server-wrapper.js` wrapper. It does not remove unrelated Stremio libraries, addons, or user settings. Rollback is safe to repeat.

---

## 8. Reinstall Procedure

After rollback, reinstall from the published checkout:

```bash
cd ~/stremio-mute
git checkout v1.2.4
./scripts/install.sh
./scripts/verify.sh
```

The installer recomputes the current user’s canonical app-owned absolute `SERVER_PATH`, proves its sandbox visibility, and removes the legacy host wrapper. It does not reuse a stale path, another user’s path, or a literal tilde. Expect `CONFIGURED` while Stremio is stopped and `RUNTIME VERIFIED` after launching Stremio and starting a stream.

The lifecycle is:

```text
install → verify → use → rollback → verify removal → reinstall → verify again
```

---

## 9. Compatibility Failure Procedure

If the verifier reports `INCOMPATIBLE` after an upstream update:

1. Do not stream through the unverified controller.
2. Run `./scripts/diagnose.sh`.
3. Submit the diagnostic output using the compatibility issue template.
4. Use `./scripts/rollback.sh` only if stock Stremio is required temporarily and the consequences are understood.
5. Wait for a compatibility update before reinstalling Stremio Mute.

The wrapper’s fail-closed behavior is intentional: it exits instead of silently falling back to unmodified `server.js`.
