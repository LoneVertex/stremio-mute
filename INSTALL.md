# Installation Guide — Stremio Mute

This guide explains how to install, verify, and manage Stremio Mute on Linux.

---

## Prerequisites

1. **Linux Distribution:** Modern Linux distribution with Flatpak (Fedora, Arch Linux, Ubuntu, Debian, openSUSE, etc.).
2. **Flatpak:** `flatpak` CLI installed (`flatpak --version`).
3. **Stremio Flatpak:** Stremio installed via Flatpak (`com.stremio.Stremio` from Flathub).
   ```bash
   flatpak install flathub com.stremio.Stremio
   ```
4. **Node.js / Bash:** Standard Node.js (`node --version`) and Bash tools for script verification.

---

## Automated Installation

### Step 1: Clone the Repository
```bash
git clone https://github.com/LoneVertex/stremio-mute.git
cd stremio-mute
```

### Step 2: Run the Hardened Installer
```bash
./scripts/install.sh
```

**Installer Execution Flow & Pre-Flight Order:**
1. **Detect Prerequisites:** Verifies `flatpak` and `node` are available.
2. **Inspect Stremio Flatpak:** Checks `com.stremio.Stremio` is installed.
3. **Pre-Flight Compatibility Validation:** Runs in-sandbox assertion checking that all 3 fingerprints match `server.js` **before** modifying anything. If a mismatch is detected, installation halts cleanly with code 2.
4. **Validate Wrapper Syntax:** Performs `node -c` syntax check.
5. **Stage Wrapper:** Copies `src/server-wrapper.js` to `$HOME/.stremio-server/server-wrapper.js` (`0644`).
6. **Apply Flatpak Override:** Computes the current user’s absolute wrapper path and stores it with `flatpak override --user`; for example, `/home/current-user/.stremio-server/server-wrapper.js`.
7. **Verify the Persisted Override:** Confirms `flatpak override --user --show com.stremio.Stremio` contains exactly `SERVER_PATH=/home/current-user/.stremio-server/server-wrapper.js` for the current user.
8. **Run Verification:** Executes `./scripts/verify.sh`.

The shell expression `$HOME/.stremio-server/server-wrapper.js` is only a convenient way to describe the path. The actual Flatpak environment value is an absolute path computed from the current user’s home directory. Never configure or document `SERVER_PATH=~/.stremio-server/server-wrapper.js` as the persisted value; Flatpak and the Stremio runtime do not expand that literal tilde.

---

## Operational Verification

Inspect installation health at any time:
```bash
./scripts/verify.sh
```

- **Before launching Stremio:** The output will display `STATUS: CONFIGURED`.
- **After launching Stremio and confirming the loopback controller and heartbeat:** The output will display `STATUS: RUNTIME VERIFIED`.

---

## Launching Stremio

Launch Stremio normally through your desktop menu (KDE Plasma Application Launcher, KRunner, GNOME menu) or via CLI:
```bash
flatpak run com.stremio.Stremio
```

Flatpak automatically injects `SERVER_PATH`, activating Stremio Mute in memory.

---

## Rollback & Uninstallation

To cleanly remove Stremio Mute and restore default Stremio behavior:
```bash
./scripts/rollback.sh
```
This unsets the Flatpak user environment override and removes the canonical `$HOME/.stremio-server/server-wrapper.js` wrapper. It also removes the legacy sandbox-local wrapper path left by older releases, if present. Your library, addons, and user settings are preserved.
