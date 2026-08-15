# Support Policy — Stremio Mute

## Getting Help

1. **Review Documentation:** Read [README.md](README.md), [INSTALL.md](INSTALL.md), [COMPATIBILITY.md](COMPATIBILITY.md), and [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
2. **Check the Installed State:** From the checkout, run `./scripts/verify.sh`.
3. **Inspect the Persisted Path When Needed:** Run `flatpak override --user --show com.stremio.Stremio`. The `SERVER_PATH` value must be an absolute path to the current user’s wrapper; do not configure a literal tilde value.
4. **Generate Diagnostic Snapshot:** Run `./scripts/diagnose.sh` to generate an issue-safe report.
5. **Open an Issue:** Submit a report via [GitHub Issues](https://github.com/LoneVertex/stremio-mute/issues):
   - **Bug Report:** For unexpected behavior or errors during installation or verification.
   - **Compatibility Report:** For findings on a new Stremio version or Linux distribution.

When reporting a runtime issue, include the Stremio Mute version, verifier state, Stremio and Flatpak versions, operating system and desktop environment, lifecycle context such as reboot/update/reinstall, and endpoint evidence if available. When runtime is active, include the reported controller `version`, `sourceSha256`, `active`, `muted`, `uploads`, `rechokeSlots`, and `wireRequestBlocked` fields. Do not include credentials, private paths, or other sensitive data. Do not claim `RUNTIME VERIFIED` or zero peer-piece upload without corresponding evidence.

---

## Out of Scope Support Requests

The project does not provide support for:
- Third-party Stremio addons, torrent indexers, or scrapers.
- Debrid providers or external proxy streaming configurations.
- Non-Flatpak Stremio installations unless community contributors maintain support.
- Core Stremio application bugs unrelated to the upload controller.
- A separate `com.stremio.Service` component; the documented setup targets `com.stremio.Stremio` and does not require a separate service application.
