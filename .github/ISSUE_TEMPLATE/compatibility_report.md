---
name: Compatibility Report
about: Report compatibility findings for a new Stremio release or Linux distribution
title: '[COMPATIBILITY] '
labels: compatibility
assignees: ''
---

**Environment Information**
- Linux Distribution & Version:
- Desktop Environment (KDE / GNOME / etc.):
- Stremio Version:
- Flatpak Version:

**Diagnostic Snapshot**
Run `./scripts/diagnose.sh` and paste the output below:

```text
(Paste output of ./scripts/diagnose.sh here)
```

**Verification Results**
- Did `./scripts/verify.sh` report `CONFIGURED`, `RUNTIME VERIFIED`, `INCOMPATIBLE`, `NOT PROTECTED`, `NOT INSTALLED`, or `ERROR`?
- What exact `SERVER_PATH` value is shown by `flatpak override --user --show com.stremio.Stremio`? Do not paste a literal tilde value as a configuration.
- Did playback start normally?
- After launching Stremio, did `http://127.0.0.1:11470/heartbeat` respond?
- Did `http://127.0.0.1:11470/zero-upload-controller` respond?
- If upload was measured, describe the method and distinguish peer-piece upload from aggregate host traffic. Do not claim zero bytes without evidence.

**Lifecycle Context**
- Did the issue occur after installation, reboot, Stremio restart, rollback/reinstall, or a Stremio/Flatpak update?
