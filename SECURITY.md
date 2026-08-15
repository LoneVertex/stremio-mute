# Security Policy — Stremio Mute

## Supported Versions

| Version | Supported |
|---|---|
| 1.2.x, including v1.2.3 | Yes |
| < 1.2.0 | No |

---

## Reporting a Vulnerability

If you discover a security issue or unexpected upload leakage in the controller:

1. **Do NOT open a public GitHub issue.**
2. Report the vulnerability privately to maintainers via GitHub Private Vulnerability Reporting or by contacting `venom010101` on GitHub.
3. Include:
   - Stremio Flatpak version and OS details
   - Output of `./scripts/diagnose.sh`
   - Reproduction steps and captured packet telemetry if available

We will acknowledge reports within 48 hours where possible and prioritize fail-closed fixes for confirmed safety issues. Runtime reports should include the controller endpoint version and source SHA256 when investigating stale or alternate wrapper execution.
