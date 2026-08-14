# Frequently Asked Questions (FAQ) — Stremio Mute

### Q: Will this reduce or slow down my streaming download speed?
**A:** No. Under the BitTorrent protocol (BEP 3), download throughput depends on remote seeders unchoking the local client and sending requested media piece blocks. Stremio Mute only modifies your local choking state towards peers (preventing you from serving piece blocks to them). In empirical tests, download throughput is identical to stock Stremio.

### Q: Does this require root, `sudo`, or system firewall changes?
**A:** No. Stremio Mute runs entirely in user space inside the unprivileged Flatpak sandbox environment. It does not alter your host firewall, nftables, systemd units, or network interfaces.

### Q: Is this an addon, scraper, or Debrid proxy?
**A:** No. This project is strictly a local engine-level policy enforcement tool for Stremio's embedded BitTorrent engine. It does not use or integrate with any third-party addons, torrent scrapers, external proxies, or Debrid accounts.

### Q: Does this eliminate all network traffic from Stremio?
**A:** No. It suppresses **BitTorrent media-piece serving (seeding)**. Minimal protocol discovery traffic (such as BitTorrent tracker announcements exchanging ~200 bytes of discovery metadata to join swarms and discover seeders) remains active as required to stream media.

### Q: What happens when Stremio updates?
**A:** Stremio Mute operates under a **fail-closed** safety model. If an upstream update modifies `server.js` code structure such that any fingerprint mismatches, Stremio's streaming server refuses to launch (`process.exit(1)`) rather than silently leaking upload data. You can run `./scripts/verify.sh` after any update to confirm status.

### Q: How can I verify it is actively working?
**A:** Run `./scripts/verify.sh` while playing any video stream. The tool directly queries the local loopback IPC controller endpoint on `http://127.0.0.1:11470/zero-upload-controller` and confirms active invariant enforcement.
