# Versioning Policy — Stremio Mute

This project adheres to [Semantic Versioning 2.0.0](https://semver.org/).

---

## 1. Controller Versioning vs Target Stremio Version

We maintain strict semantic separation between the **Controller Version** and **Target Stremio Version**:

```text
Controller Version (e.g. 1.2.4):
  Tracks features, fixes, and improvements in this repository. The current controller release is v1.2.4, and its runtime endpoint must report `version: 1.2.4`.

Target Stremio Version (e.g. v1.2.0):
  The upstream Flatpak application release verified against our structural fingerprints. This is independent of the controller version: controller v1.2.4 does not mean upstream Stremio v1.2.4. The currently documented verified target is Stremio v1.2.0, as recorded in COMPATIBILITY.md.
```

---

## 2. Version Increment Rules

- **MAJOR (X.0.0):** Breaking architectural redesigns or backward-incompatible changes to CLI scripts.
- **MINOR (1.X.0):** New diagnostic features, updated structural fingerprints for newly verified Stremio releases, or improved verifiers.
- **PATCH (1.2.X):** Bug fixes, diagnostic improvements, deployment corrections, documentation updates, or other non-architectural corrections. The v1.2.2 absolute-path repair, v1.2.3 runtime metadata consistency correction, and v1.2.4 Flatpak-visible deployment repair are patch-level controller changes.
