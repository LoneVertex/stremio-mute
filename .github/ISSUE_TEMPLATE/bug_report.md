---
name: Bug Report
about: Create a report to help us improve Stremio Mute
title: '[BUG] '
labels: bug
assignees: ''
---

**Describe the Bug**
A clear and concise description of what the issue is.

**Version and Environment**
- Stremio Mute Version:
- Stremio Version:
- Linux Distribution and Desktop Environment:
- Flatpak Version:

**Diagnostic Snapshot**
Run `./scripts/diagnose.sh` and paste the output below:

```text
(Paste output of ./scripts/diagnose.sh here)
```

**Verification Output**
Run `./scripts/verify.sh` and paste the output below:

```text
(Paste output of ./scripts/verify.sh here)
```

If the endpoint is reachable, include its reported `version`, `sourceSha256`, `active`, `muted`, `uploads`, `rechokeSlots`, and `wireRequestBlocked` fields. State whether `version` matches `VERSION` and `sourceSha256` matches the installed wrapper. Redact credentials, private paths, and other sensitive data.

**Steps to Reproduce**
1. Step 1
2. Step 2
3. Step 3

**Expected Behavior**
A clear description of what you expected to happen.
