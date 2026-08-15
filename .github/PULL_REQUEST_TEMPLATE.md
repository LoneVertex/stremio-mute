## Description
Provide a concise summary of the change and the problem it solves.

## Root Cause & Invariant Preservation
Explain the technical mechanism of the change:
- [ ] Preserves `rechokeSlots = 0` invariant
- [ ] Preserves `EngineFS.getDefaults().uploads = 0` invariant
- [ ] Preserves `wire.on("request")` piece upload neutralization
- [ ] Preserves fail-closed behavior on structural mismatch
- [ ] Strictly forbids fallback to unpatched/stock server
- [ ] Modifies zero vendor files on disk

## Scope Boundaries
- [ ] No third-party addons, scrapers, indexers, or Debrid integrations
- [ ] No external proxies, VPNs, or streaming relays
- [ ] Pure user-space execution inside Flatpak sandbox (no sudo/root)
- [ ] Uses one canonical app-owned Flatpak deployment path; no broad home filesystem permission was added
- [ ] Removes or safely neutralizes only project-managed legacy wrapper copies

## Compatibility & Verification Evidence
- [ ] `bash tests/static/test_syntax.sh` passed
- [ ] `bash tests/compatibility/test_compatibility_fixtures.sh` passed
- [ ] `bash tests/integration/test_install_rollback.sh` passed
- [ ] `bash tests/static/test_absolute_path.sh` passed
- [ ] `bash tests/static/test_controller_version.sh` passed
- [ ] `bash tests/static/test_stale_process_install.sh` passed
- [ ] `bash scripts/repo-audit.sh` passed
- [ ] Runtime endpoint `version` matches repository `VERSION` and `sourceSha256` matches the canonical installed wrapper
- [ ] Canonical `SERVER_PATH` is readable inside the Flatpak sandbox and the old host-only path is rejected
- [ ] Live streaming test verified, or explicitly marked unverified when no suitable Flatpak desktop environment is available
- [ ] Any `RUNTIME VERIFIED` claim is backed by endpoint, heartbeat, invariant, and environment evidence

```text
(Paste verify.sh or test output here)
```
