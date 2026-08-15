# Frequently Asked Questions — Stremio Mute v1.2.2

### Will this reduce or slow down my streaming download speed?

Stremio Mute is designed to suppress local BitTorrent media-piece uploads while preserving ordinary download requests. Actual throughput still depends on remote seeders, swarm conditions, and the upstream Stremio engine. The project does not guarantee a particular download speed.

### Why is `SERVER_PATH` an absolute path?

Flatpak passes the configured environment value to Stremio’s Node.js process. A literal tilde inside that value is not expanded as shell syntax. The installer therefore computes and stores the current user’s absolute wrapper path, for example:

```text
SERVER_PATH=/home/current-user/.stremio-server/server-wrapper.js
```

Use `$HOME/.stremio-server/server-wrapper.js` in shell commands as shorthand only. Do not manually configure `SERVER_PATH=~/.stremio-server/server-wrapper.js`.

### What should I do after a reboot?

Open a terminal and run:

```bash
cd ~/stremio-mute
./scripts/verify.sh
```

`CONFIGURED` is expected while Stremio is stopped. Launch Stremio, start a stream, and run the verifier again. Require `RUNTIME VERIFIED` before treating active runtime protection as confirmed.

### Why does `verify.sh` say `CONFIGURED` instead of `RUNTIME VERIFIED`?

`CONFIGURED` means static installation checks pass while Stremio is idle. `RUNTIME VERIFIED` requires the Stremio server to be running and the controller endpoint and heartbeat to respond. Launch Stremio and start a stream before running the verifier again.

### What should I do after a Stremio update?

Run verification before streaming:

```bash
flatpak update com.stremio.Stremio
cd ~/stremio-mute
./scripts/verify.sh
```

If the result is `INCOMPATIBLE`, run `./scripts/diagnose.sh` and submit a compatibility report. The wrapper is fail-closed and should not be bypassed.

### Why can the application fail after an old rollback?

Older installations may have left a sandbox-local wrapper or a stale override. v1.2.2 rollback removes the canonical wrapper, the legacy wrapper location, and the project’s exact Flatpak override. Verify removal with:

```bash
./scripts/rollback.sh
./scripts/verify.sh
```

`NOT INSTALLED` is the expected state after a successful rollback. Reinstall with `./scripts/install.sh` to regenerate the current user’s absolute path.

### How can I verify the running controller?

Run:

```bash
./scripts/verify.sh
```

For optional loopback inspection while Stremio is running:

```bash
curl -fsS http://127.0.0.1:11470/heartbeat
curl -fsS http://127.0.0.1:11470/zero-upload-controller
```

Missing or malformed telemetry is not proof of protection.

### Does the project require `com.stremio.Service`?

The documented installation targets the `com.stremio.Stremio` Flatpak and configures its user-level `SERVER_PATH` override. The repository’s current setup does not instruct users to install or configure a separate `com.stremio.Service` application. Whether a particular Stremio distribution exposes an additional service component is environment-specific and remains unverified by this project; do not add one unless Stremio’s own packaging requires it.

### Does this require root, `sudo`, or system firewall changes?

No. The project is designed to run in user space through the Flatpak user override and does not alter host firewall rules, nftables, systemd units, or network interfaces.

### Is this an addon, scraper, or Debrid proxy?

No. Stremio Mute is a local engine-level policy controller for the Stremio Flatpak. It is not a content provider, scraper, third-party addon, catalog provider, proxy, VPN, or Debrid client.

### Does this eliminate all network traffic from Stremio?

No. It targets BitTorrent media-piece serving. Discovery and control traffic required to locate and communicate with peers remains part of normal operation.
