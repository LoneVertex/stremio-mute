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
5. **Stage Wrapper:** Copies `src/server-wrapper.js` to `~/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js` (`0644`).
6. **Apply Flatpak Override:** Sets `SERVER_PATH=~/.stremio-server/server-wrapper.js` via `flatpak override --user`.
7. **Run Verification:** Executes `./scripts/verify.sh`.

---

## Operational Verification

Inspect installation health at any time:
```bash
./scripts/verify.sh
```

- **Before launching Stremio:** The output will display:
  `STATUS: CONFIGURED (STATIC VALIDATION PASSED)`
- **After launching Stremio and streaming:** The output will display:
  `STATUS: RUNTIME VERIFIED (UPLOADS MUTED)`

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
This unsets the Flatpak user environment override and removes the sandboxed wrapper script. Your library, addons, and user settings are preserved.
