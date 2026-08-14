## Description
Provide a concise summary of the change and the problem it solves.

## Root Cause & Mechanism
Explain the technical mechanism of the change.

## Security & Safety Impact
- [ ] Preserves fail-closed behavior on structural mismatch
- [ ] No fallback to unpatched/stock server
- [ ] No third-party addons, scrapers, or Debrid integrations
- [ ] Pure user-space execution (no sudo/root required)

## Compatibility Impact
- Stremio versions tested:
- Linux distributions tested:

## Testing & Verification Evidence
- [ ] `bash tests/static/test_syntax.sh` passed
- [ ] `bash tests/compatibility/test_compatibility_fixtures.sh` passed
- [ ] `bash scripts/repo-audit.sh` passed
- [ ] Live streaming test verified (0 bytes peer piece upload)

```text
(Paste verify.sh or test output here)
```
