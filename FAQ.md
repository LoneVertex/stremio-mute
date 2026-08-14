# Frequently Asked Questions (FAQ)

### Q: Will this reduce my download speed?
**A:** No. Under the BitTorrent protocol (BEP 3), your download speed depends on remote peers unchoking you and providing piece blocks. The controller only modifies your local choking state towards peers (preventing you from serving pieces to them). In live tests, download speeds remain identical to stock Stremio.

### Q: Does this require root / `sudo`?
**A:** No. The entire installation and runtime operation execute with standard user permissions inside the unprivileged Flatpak sandbox environment.

### Q: Is this an addon or Debrid proxy?
**A:** No. This project is strictly a local engine controller for the native BitTorrent streaming engine. It does not use any third-party addons, scrapers, proxies, or Debrid accounts.

### Q: What happens if Stremio updates?
**A:** If an update changes `server.js` code structure, the controller fails closed (`process.exit(1)`) with a clear error rather than silently leaking upload data. You can run `./scripts/verify.sh` to check compatibility after any update.

### Q: How do I verify it is actually working?
**A:** Run `./scripts/verify.sh` while Stremio is playing a video. The tool directly queries the local loopback IPC controller endpoint on `127.0.0.1:11470/zero-upload-controller` and confirms active enforcement.
