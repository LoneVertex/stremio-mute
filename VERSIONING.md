# Versioning Policy — Stremio Zero-Upload Controller

This project adheres to [Semantic Versioning 2.0.0](https://semver.org/).

---

## 1. Controller Versioning vs Stremio Versioning

We maintain strict separation between the **Controller Version** and **Target Stremio Version**:

```text
Controller Version (e.g. 1.2.0):
  Tracks features, fixes, and updates to this repository's codebase.

Target Stremio Version (e.g. v1.2.0):
  The specific upstream Flatpak release verified against the controller's fingerprints.
```

---

## 2. Version Increment Rules

- **MAJOR (X.0.0):** Breaking changes to script CLI interfaces, dropping support for major distributions, or architectural redesigns.
- **MINOR (1.X.0):** New diagnostic features, compatibility fingerprint updates for new Stremio versions, or enhanced verification tooling.
- **PATCH (1.2.X):** Bug fixes, diagnostic refinements, documentation improvements.
