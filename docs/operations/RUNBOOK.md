# Operational Runbook — Stremio Mute

**Audience:** System Administrators, Desktop Linux Users, and Power Users  
**System Target:** Linux (Flatpak Stremio `com.stremio.Stremio`)  

---

## 1. Day-1 Installation & Setup

### Step 1: Clone Repository
```bash
git clone https://github.com/LoneVertex/stremio-mute.git
cd stremio-mute
```

### Step 2: Install Stremio Mute
```bash
./scripts/install.sh
```
*Note: The installer automatically checks Stremio engine compatibility before making changes.*

### Step 3: Verify Static Configuration
```bash
./scripts/verify.sh
```
Confirm output indicates: `STATUS: CONFIGURED`. This confirms static configuration only; it does not claim that Stremio is running.

### Step 4: Launch Stremio & Verify Runtime
1. Start Stremio from your desktop application launcher or terminal (`flatpak run com.stremio.Stremio`).
2. Play any video stream.
3. In a terminal, run:
   ```bash
   ./scripts/verify.sh
   ```
4. Confirm output indicates: `STATUS: RUNTIME VERIFIED`. This requires the active loopback controller endpoint and heartbeat to respond.

---

## 2. Absolute SERVER_PATH Rule

The installer computes the wrapper location from the current user’s home directory using the shell expression `$HOME/.stremio-server/server-wrapper.js`, then stores the resulting absolute path in Flatpak. For example, the persisted value may be `/home/current-user/.stremio-server/server-wrapper.js`. The literal `SERVER_PATH=~/.stremio-server/server-wrapper.js` must never be stored because the Flatpak environment and Stremio’s Node process do not expand that tilde representation.

Inspect the actual value with:

```bash
flatpak override --user --show com.stremio.Stremio
```

The reported `SERVER_PATH` must exactly equal the current user’s absolute wrapper path.

---

## 3. Upstream Stremio Update Procedure

When Flatpak updates the Stremio package:
```bash
flatpak update com.stremio.Stremio
```

### Post-Update Operational Check:
Run the verifier immediately:
```bash
./scripts/verify.sh
```

- **Scenario A (Status is `CONFIGURED`):** The update preserves the expected internal code structure. Launch Stremio normally.
- **Scenario B (Status is `INCOMPATIBLE`):** The update modified `server.js` minification or layout.
  - The controller **fails closed** upon launch, preventing unmuted uploads.
  - Generate diagnostics:
    ```bash
    ./scripts/diagnose.sh
    ```
  - Open a [Compatibility Issue](https://github.com/LoneVertex/stremio-mute/issues) with the diagnostic report.
  - Optional temporary rollback to stock Stremio while awaiting a controller update:
    ```bash
    ./scripts/rollback.sh
    ```

---

## 4. Clean Rollback Procedure

To cleanly remove Stremio Mute and restore stock Stremio configuration:
```bash
./scripts/rollback.sh
```
Confirm output indicates `ROLLBACK SUCCESSFUL`.
