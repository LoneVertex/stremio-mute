# Frequently Asked Questions — Stremio Mute v1.2.5

### Will this reduce or slow down my streaming download speed?

Stremio Mute is designed to suppress local BitTorrent media-piece uploads while preserving ordinary download requests. Actual throughput still depends on remote seeders, swarm conditions, and the upstream Stremio engine. The project does not guarantee a particular download speed.

### Why is `SERVER_PATH` an absolute path?

Flatpak passes the configured environment value to Stremio’s Node.js process. A literal tilde inside that value is not expanded as shell syntax. The installer therefore computes and stores the current user’s absolute app-owned wrapper path, for example:

```text
SERVER_PATH=/home/current-user/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js
```

Use `$HOME/.var/app/com.stremio.Stremio/.stremio-server/server-wrapper.js` in shell commands as shorthand only. The former `$HOME/.stremio-server/server-wrapper.js` host-only location is legacy. Do not manually configure the **OLD / INVALID / HISTORICAL** `SERVER_PATH=~/.stremio-server/server-wrapper.js` form.

### What should I do after a reboot?

Open a terminal and run:

```bash
cd ~/stremio-mute
./scripts/verify.sh
```

`CONFIGURED` is expected while Stremio is stopped. Launch Stremio, start a stream, and run the verifier again. Require `RUNTIME VERIFIED` before treating active runtime protection as confirmed.

### Why does `verify.sh` say `CONFIGURED` instead of `RUNTIME VERIFIED`?

`CONFIGURED` means the canonical app-owned installation checks pass while Stremio is idle, including exact override, repository byte match, sandbox visibility, and legacy cleanup. `RUNTIME VERIFIED` additionally requires the Stremio server to be running, the controller to be active, the heartbeat to respond, the runtime version to match `VERSION`, the endpoint `sourceSha256` to match the canonical installed wrapper, no legacy wrapper to compete, and the upload-suppression invariants to be present. Launch Stremio and start a stream before running the verifier again.

### What should I do after a Stremio update?

Run verification before streaming:

```bash
flatpak update com.stremio.Stremio
cd ~/stremio-mute
./scripts/verify.sh
```

If the result is `INCOMPATIBLE`, run `./scripts/diagnose.sh` and submit a compatibility report. Do not stream until compatibility is reviewed, and do not disable the fail-closed wrapper to bypass the failure.

### Why can the application fail after an old rollback?

Older installations may have left a host-only wrapper or a stale override. v1.2.5 rollback restores `SERVER_PATH=/app/libexec/stremio/server.js`, verifies the effective stock path inside the sandbox, and then removes the canonical app-owned wrapper and legacy host wrapper. Verify removal with:

```bash
./scripts/rollback.sh
./scripts/verify.sh
```

`NOT INSTALLED` is the expected state for Mute after a successful rollback. Stock Stremio must still be launchable. If an older rollback produced `Failed to read SERVER_PATH env: NotPresent`, restore the stock path with `flatpak override --user --env=SERVER_PATH=/app/libexec/stremio/server.js com.stremio.Stremio`. Reinstall with `./scripts/install.sh` only when you intend to enable Mute again.

### Why does the installer stop Stremio?

A Node process keeps the wrapper it loaded in memory. Replacing the wrapper file on disk does not change a process that is already running, so it could otherwise continue reporting an older controller version. v1.2.5 stops a running Stremio process before deploying new wrapper bytes, removes the legacy host wrapper, and stages the canonical app-owned wrapper; the next launch loads the current release.

### Why can a running process report an older controller version?

The endpoint reports the version captured when the wrapper process started. If it reports an older version than the installed release, the process is stale or another wrapper copy is serving the endpoint. Run `./scripts/install.sh`, relaunch Stremio, and require `RUNTIME VERIFIED`; do not manually edit arbitrary runtime state.

### What does `sourceSha256` mean?

`sourceSha256` is the SHA256 identity of the wrapper file that is executing the controller. `verify.sh` compares it with the canonical app-owned wrapper bytes and also requires the endpoint version to match the repository `VERSION`. A mismatch means the currently running process is not positively identified as the expected deployment.

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

The endpoint reports the controller version and executing-wrapper SHA256 in addition to the policy state. `verify.sh` rejects a running process whose version or source hash does not match the current repository and installed wrapper. Missing or malformed telemetry is not proof of protection.

### Does the project require `com.stremio.Service`?

The documented installation targets the `com.stremio.Stremio` Flatpak and configures its user-level `SERVER_PATH` override. The repository’s current setup does not instruct users to install or configure a separate `com.stremio.Service` application. Whether a particular Stremio distribution exposes an additional service component is environment-specific and remains unverified by this project; do not add one unless Stremio’s own packaging requires it.

### Does this require root, `sudo`, or system firewall changes?

No. The project is designed to run in user space through the Flatpak user override and does not alter host firewall rules, nftables, systemd units, or network interfaces.

### Is this an addon, scraper, or Debrid proxy?

No. Stremio Mute is a local engine-level policy controller for the Stremio Flatpak. It is not a content provider, scraper, third-party addon, catalog provider, proxy, VPN, or Debrid client.

### Does this eliminate all network traffic from Stremio?

No. The target guarantee is zero observed BitTorrent peer-piece upload from the protected engine, not zero total outbound packets. Tracker/control, DNS, HTTPS, telemetry, and other background traffic may remain part of normal operation.
