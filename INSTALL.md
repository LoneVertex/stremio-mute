# Installation Guide — Stremio Zero-Upload Controller

This guide explains how to install, verify, and manage the Stremio Zero-Upload Controller on Linux.

---

## Prerequisites

1. **Linux Distribution:** Any modern Linux distribution supporting Flatpak (Fedora, Arch Linux, Ubuntu, Debian, openSUSE, etc.).
2. **Flatpak:** `flatpak` CLI installed (`flatpak --version`).
3. **Stremio Flatpak:** Stremio installed via Flatpak (`com.stremio.Stremio` from Flathub).
   ```bash
   flatpak install flathub com.stremio.Stremio
   ```
4. **Node.js / Bash:** Standard Node.js and Bash tools available for verification.

---

## Automated Installation

### Step 1: Clone or Download this Repository
```bash
git clone https://github.com/venom010101/stremio-zero-upload.git
cd stremio-zero-upload
```

### Step 2: Run the Installer
```bash
./scripts/install.sh
```

**What `install.sh` does:**
1. Verifies that `com.stremio.Stremio` is installed via Flatpak.
2. Copies `src/server-wrapper.js` into Stremio's persistent sandbox storage (`~/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js`) with `0644` permissions.
3. Sets a Flatpak user-level environment override:
   ```bash
   flatpak override --user --env=SERVER_PATH=~/.stremio-server/server-wrapper.js com.stremio.Stremio
   ```
4. Automatically runs `./scripts/verify.sh` to confirm static configuration.

---

## Verifying the Installation

After running the installer, execute the health check:
```bash
./scripts/verify.sh
```

- **Before launching Stremio:** The output will display:
  `STATUS: CONFIGURED (STATIC VALIDATION PASSED)`
- **After launching Stremio:** The output will query the local loopback IPC endpoint and display:
  `STATUS: RUNTIME VERIFIED (ZERO UPLOAD ENFORCED)`

---

## Launching Stremio

Launch Stremio through any standard method:
- KDE Plasma Application Launcher / KRunner
- GNOME Application Menu
- Terminal: `flatpak run com.stremio.Stremio`
- Desktop shortcuts and URL handlers (`stremio://`)

Flatpak automatically injects `SERVER_PATH` into the sandbox, activating the zero-upload controller without any manual terminal commands required.

---

## Uninstallation / Rollback

To cleanly remove the controller and restore default Stremio behavior:
```bash
./scripts/rollback.sh
```
This unsets the Flatpak environment override and removes the sandboxed wrapper script. It does not alter your library, addons, or user settings.
