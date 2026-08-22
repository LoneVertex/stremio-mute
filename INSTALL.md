# Installation Guide — Stremio Mute

This guide explains how to install, verify, operate, update, roll back, and reinstall Stremio Mute v1.2.5 on a supported Linux Flatpak desktop.

> **Important:** Use `$HOME` in shell commands when referring to the current user’s home directory. The Flatpak `SERVER_PATH` value itself is stored as an **absolute filesystem path** in app-owned storage. The former host-only `$HOME/.stremio-server/server-wrapper.js` location is legacy; the literal `SERVER_PATH=~/.stremio-server/server-wrapper.js` is **OLD / INVALID / HISTORICAL** and must never be configured.

---

## Prerequisites

1. **Linux with Flatpak:** A supported Linux desktop with the `flatpak` CLI available.
2. **Stremio Flatpak:** Stremio installed as `com.stremio.Stremio`, preferably from Flathub.
3. **Bash and Git:** Bash is required by the scripts, and Git is required for the checkout and later updates.
4. **Host Node.js:** Not required for installation. When available, the installer uses host Node.js for an additional wrapper syntax check; the repository test suite also validates JavaScript syntax.

Check the required host tools and Stremio installation:

```bash
flatpak --version
git --version
flatpak info com.stremio.Stremio
```

If Stremio is not installed, install it through Flatpak:

```bash
flatpak install flathub com.stremio.Stremio
```

---

## Automated Installation

### Step 1: Clone the v1.2.5 Checkout

```bash
git clone https://github.com/LoneVertex/stremio-mute.git
cd stremio-mute
git checkout v1.2.5
```

If you already have the checkout, update it before reinstalling:

```bash
cd ~/stremio-mute
git fetch --tags origin
git checkout v1.2.5
```

### Step 2: Run the Installer

```bash
./scripts/install.sh
```

The installer performs the following operations in order:

1. It checks for the Flatpak CLI and confirms that `com.stremio.Stremio` is installed.
2. It runs the in-sandbox compatibility pre-flight against Stremio’s bundled `server.js` before staging files or changing the Flatpak override.
3. It verifies the wrapper source and, when host Node.js is available, performs a syntax check.
4. It stops any running `com.stremio.Stremio` process so a previously loaded wrapper cannot continue serving stale in-memory metadata.
5. It stages the wrapper at `$HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js` with mode `0644` and verifies that the staged bytes match the repository source.
6. It removes the project-managed legacy host wrapper at `$HOME/.stremio-server/server-wrapper.js` so only one active deployment location remains.
7. It computes the current user’s canonical absolute app-owned path and stores that value in the Flatpak user override.
8. It proves that the canonical wrapper is readable inside the Flatpak sandbox.
9. It verifies that `flatpak override --user --show com.stremio.Stremio` contains the exact canonical absolute `SERVER_PATH` and runs `./scripts/verify.sh`.

The shell expression `$HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js` is shorthand only. For a user whose home is `/home/current-user`, the persisted value must be:

```text
SERVER_PATH=/home/current-user/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js
```

Do not manually write `SERVER_PATH=~/.stremio-server/server-wrapper.js`. Flatpak and Stremio’s Node process do not expand that literal tilde, and the old host-only location is not the canonical runtime deployment.

---

## Verification and Launch

Run the verifier at any time:

```bash
./scripts/verify.sh
```

When Stremio is stopped, a correctly installed v1.2.5 checkout should report:

```text
STATUS: CONFIGURED
```

`CONFIGURED` confirms the canonical app-owned wrapper, exact absolute override, repository byte match, sandbox visibility, legacy cleanup, and compatibility checks. It does not claim that the Stremio server is running.

Launch Stremio normally through the desktop application launcher or the command line:

```bash
flatpak run com.stremio.Stremio
```

After the streaming server is running, verify again:

```bash
./scripts/verify.sh
```

A protected running server should report:

```text
STATUS: RUNTIME VERIFIED
```

`RUNTIME VERIFIED` requires the active loopback controller and heartbeat evidence, a controller version matching the repository `VERSION`, an executing-wrapper `sourceSha256` matching the installed wrapper bytes, and the required upload-suppression invariants. If the server is not running, `CONFIGURED` is expected rather than a failure.

---

## After Reboot

After restarting Fedora or another supported Linux desktop:

```bash
cd ~/stremio-mute
./scripts/verify.sh
```

If Stremio has not been launched yet, `STATUS: CONFIGURED` is expected. Launch Stremio, start a stream, and run the verifier again:

```bash
flatpak run com.stremio.Stremio
./scripts/verify.sh
```

The expected running state is `STATUS: RUNTIME VERIFIED`. For optional manual checks, inspect the loopback endpoints documented in [TROUBLESHOOTING.md](TROUBLESHOOTING.md): `/heartbeat` should report success, and `/zero-upload-controller` should expose `version`, `sourceSha256`, `active`, `muted`, `uploads`, `rechokeSlots`, and `wireRequestBlocked`. A runtime reporting an older controller version indicates stale process state and must be restarted through the supported installer lifecycle before protection is accepted.

---

## After a Stremio or Flatpak Update

Because Stremio Mute patches exact internal structures in the bundled `server.js`, always verify before streaming after an update:

```bash
flatpak update com.stremio.Stremio
cd ~/stremio-mute
./scripts/verify.sh
```

If the verifier reports `INCOMPATIBLE`, do not stream through the controller. The wrapper is designed to fail closed; do not disable protection to bypass the compatibility failure. Generate a diagnostic report and submit a [compatibility issue](https://github.com/LoneVertex/stremio-mute/issues):

```bash
./scripts/diagnose.sh
```

---

## Rollback, Removal Verification, and Reinstall

To restore stock Stremio behavior:

```bash
cd ~/stremio-mute
./scripts/rollback.sh
./scripts/verify.sh
```

After a successful rollback, the verifier should report `STATUS: NOT INSTALLED`. Rollback restores the stock `SERVER_PATH=/app/libexec/stremio/server.js` inside the Flatpak, then removes the project’s canonical app-owned `$HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js` wrapper and legacy host `$HOME/.stremio-server/server-wrapper.js` wrapper. It does not remove unrelated Stremio library data, addons, or user settings. The rollback verifies the stock path before deleting the Mute wrapper; if that verification fails, it stops and preserves the existing deployment.

To reinstall after rollback:

```bash
./scripts/install.sh
./scripts/verify.sh
```

Reinstallation recomputes and persists the current user’s canonical app-owned absolute `SERVER_PATH`; it does not reuse a literal tilde value, the old host-only path, or a path belonging to another user. Expect `CONFIGURED` while Stremio is stopped, followed by `RUNTIME VERIFIED` after launching Stremio and starting a stream.

---

## Further Documentation

- [README.md](README.md) — project overview and quickstart
- [ARCHITECTURE.md](ARCHITECTURE.md) — controller lifecycle and fail-closed design
- [COMPATIBILITY.md](COMPATIBILITY.md) — supported, verified, unverified, and incompatible states
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — diagnostics and runtime failure checks
- [Operational Runbook](docs/operations/RUNBOOK.md) — complete day-to-day procedures
