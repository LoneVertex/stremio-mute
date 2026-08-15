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
- Stremio Mute Version:
- Stremio Version:
- Flatpak Version:

**Diagnostic Snapshot**
Run `./scripts/diagnose.sh` and paste the output below:

```text
(Paste output of ./scripts/diagnose.sh here)
```

**Verification Results**
- Did `./scripts/verify.sh` report `CONFIGURED`, `RUNTIME VERIFIED`, `INCOMPATIBLE`, `NOT PROTECTED`, `NOT INSTALLED`, or `ERROR`?
- What exact `SERVER_PATH` value is shown by `flatpak override --user --show com.stremio.Stremio`? The expected current form is an absolute path under `$HOME/.var/app/com.stremio.Stremio/.stremio-server/`; do not paste a literal tilde value as a configuration.
- Did the verifier prove that the canonical wrapper is readable inside the Flatpak sandbox?
- Did the diagnostic report find the legacy host wrapper at `$HOME/.stremio-server/server-wrapper.js`? Do not include private usernames or unredacted private paths.
- Did playback start normally?
- After launching Stremio, did `http://127.0.0.1:11470/heartbeat` respond?
- Did `http://127.0.0.1:11470/zero-upload-controller` respond?
- If it responded, what values did it report for `version`, `sourceSha256`, `active`, `muted`, `uploads`, `rechokeSlots`, and `wireRequestBlocked`? Redact credentials, private paths, and other sensitive data.
- Does the endpoint `version` match the Stremio Mute `VERSION`, and does `sourceSha256` match the canonical installed wrapper? If not, report the mismatch exactly.
- If upload was measured, describe the method and distinguish peer-piece upload from aggregate host traffic. Do not claim zero bytes without evidence.

**Lifecycle Context**
- Did the issue occur after installation, reboot, Stremio restart, rollback/reinstall, or a Stremio/Flatpak update?
