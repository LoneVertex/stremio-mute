# Versioning Policy — Stremio Mute

This project adheres to [Semantic Versioning 2.0.0](https://semver.org/).

---

## 1. Controller Versioning vs Target Stremio Version

We maintain strict semantic separation between the **Controller Version** and **Target Stremio Version**:

```text
Controller Version (e.g. 1.2.3):
  Tracks features, fixes, and improvements in this repository. The current published controller is v1.2.3.

Target Stremio Version (e.g. v1.2.0):
  The upstream Flatpak application release verified against our structural fingerprints. This is independent of the controller version; v1.2.0 is the verified target evidence documented in COMPATIBILITY.md.
```

---

## 2. Version Increment Rules

- **MAJOR (X.0.0):** Breaking architectural redesigns or backward-incompatible changes to CLI scripts.
- **MINOR (1.X.0):** New diagnostic features, updated structural fingerprints for newly verified Stremio releases, or improved verifiers.
- **PATCH (1.2.X):** Bug fixes, diagnostic improvements, documentation updates, or other non-architectural corrections. The v1.2.2 absolute-path repair and v1.2.3 runtime metadata consistency correction are patch-level controller changes.
