# Operational Runbook — Stremio Zero-Upload Controller

**Audience:** System Administrators, Power Users, and End Users  
**System:** Linux (Flatpak Stremio)  

---

## 1. Standard Day-1 Deployment

### Step 1: Clone Repository
```bash
git clone https://github.com/venom010101/stremio-zero-upload.git
cd stremio-zero-upload
```

### Step 2: Install
```bash
./scripts/install.sh
```

### Step 3: Verify
```bash
./scripts/verify.sh
```
Confirm `STATUS: CONFIGURED (STATIC VALIDATION PASSED)`.

### Step 4: Launch & Runtime Check
1. Start Stremio from your desktop application menu.
2. Play any video stream.
3. In a terminal, run:
   ```bash
   ./scripts/verify.sh
   ```
4. Confirm `STATUS: RUNTIME VERIFIED (ZERO UPLOAD ENFORCED)`.

---

## 2. Upstream Stremio Update Procedure

When Flatpak updates Stremio:
```bash
flatpak update com.stremio.Stremio
```

### Post-Update Action:
Run the operational health check immediately:
```bash
./scripts/verify.sh
```

- **Scenario A (Status is `CONFIGURED`):** The update preserves the expected internal code structure. No action required; launch Stremio normally.
- **Scenario B (Status is `NOT PROTECTED`):** The update modified `server.js` code structure.
  - The controller will **fail closed** to prevent unsuppressed uploads.
  - Generate diagnostics:
    ```bash
    ./scripts/diagnose.sh
    ```
  - Open a [Compatibility Issue](https://github.com/venom010101/stremio-zero-upload/issues) with the diagnostic output.
  - Optional temporary fallback to stock Stremio:
    ```bash
    ./scripts/rollback.sh
    ```

---

## 3. Clean Rollback Procedure

To cleanly remove the controller:
```bash
./scripts/rollback.sh
```
Verify that `rollback.sh` outputs `ROLLBACK SUCCESSFUL`.
