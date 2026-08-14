/**
 * Stremio Zero-Upload Controller
 * 
 * Enforces in-memory zero BitTorrent peer piece uploads for Stremio Streaming Server.
 * Delivered via Flatpak user environment override (SERVER_PATH).
 * 
 * Invariants Enforced:
 *   1. rechokeSlots = 0 (Peers remain permanently choked; zero upload slots allocated)
 *   2. EngineFS.getDefaults().uploads = 0 (Engine constructor defaults to 0 upload slots)
 *   3. wire.on("request") Neutralized (Blocks disk piece reads & wire block transmission)
 * 
 * Safety & Reliability:
 *   - Idempotent: Single process execution guard.
 *   - Structural Fingerprinting: Every patch requires EXACTLY 1 occurrence in server.js.
 *   - Local IPC Status: Exposes loopback /zero-upload-controller endpoint.
 *   - Fail-Closed: Aborts execution with diagnostics if any structural mismatch occurs.
 *   - Zero Fallback: Never executes unmodified server.js upon patching failure.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const Module = require('module');

const CONTROLLER_VERSION = '1.2.0';
const TARGET_SERVER_PATH = process.env.STREMIO_TARGET_SERVER_PATH || '/app/libexec/stremio/server.js';

// Idempotence guard
if (global.__STREMIO_ZERO_UPLOAD_CONTROLLER_INITIALIZED__) {
  console.log(`[Upload-Control] Controller v${CONTROLLER_VERSION} already initialized in this process.`);
  return;
}
global.__STREMIO_ZERO_UPLOAD_CONTROLLER_INITIALIZED__ = true;

console.log(`[Upload-Control] Initializing Stremio Zero-Upload Controller v${CONTROLLER_VERSION}...`);

// Pre-flight check: Target existence
if (!fs.existsSync(TARGET_SERVER_PATH)) {
  console.error('================================================================================');
  console.error(`[Upload-Control] FATAL: Target Stremio server not found at: ${TARGET_SERVER_PATH}`);
  console.error('Action Required: Verify Flatpak installation with "flatpak info com.stremio.Stremio"');
  console.error('================================================================================');
  process.exit(1);
}

try {
  const rawCode = fs.readFileSync(TARGET_SERVER_PATH, 'utf8');

  // Structural compatibility fingerprints (each MUST occur EXACTLY once in server.js)
  const fingerprints = [
    {
      name: 'Rechoke slots allocation pattern',
      pattern: 'var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5',
      replacement: 'var rechokeIntervalId, rechokeSlots = 0 /* ZERO UPLOAD ENFORCED */'
    },
    {
      name: 'EngineFS.getDefaults options definition',
      pattern: 'MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {',
      replacement: 'MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {\n                uploads: 0, /* ZERO UPLOAD ENFORCED */'
    },
    {
      name: 'Wire piece request handling & disk read pipeline',
      pattern: 'uploadPipe.push(engine.store.read, index, (function(err, buffer) {',
      replacement: 'return cb(new Error("Upload disabled by policy")); uploadPipe.push(engine.store.read, index, (function(err, buffer) { /* ZERO UPLOAD ENFORCED */'
    }
  ];

  let patchedCode = rawCode;
  let appliedCount = 0;

  for (const fp of fingerprints) {
    const occurrences = patchedCode.split(fp.pattern).length - 1;
    if (occurrences !== 1) {
      console.error('================================================================================');
      console.error('[Upload-Control] FATAL COMPATIBILITY ERROR: Fingerprint occurrence mismatch!');
      console.error(`Fingerprint: "${fp.name}"`);
      console.error(`Expected Occurrences: 1 | Found: ${occurrences}`);
      console.error(`Controller Version: ${CONTROLLER_VERSION}`);
      console.error('Status: Stremio server code structure has changed (possibly due to an upstream update).');
      console.error('Action Required: Run "./scripts/verify.sh" to inspect compatibility.');
      console.error('FAIL-SAFE: Aborting process to prevent unsuppressed BitTorrent uploads.');
      console.error('================================================================================');
      process.exit(1);
    }

    // Apply targeted replacement
    patchedCode = patchedCode.replace(fp.pattern, fp.replacement);
    appliedCount++;
  }

  if (appliedCount !== 3) {
    console.error(`[Upload-Control] FATAL: Assertion failed. Expected 3 patches, applied ${appliedCount}. Aborting.`);
    process.exit(1);
  }

  // Intercept http.createServer to provide authoritative IPC status endpoint
  const originalCreateServer = http.createServer;
  http.createServer = function(opts, requestListener) {
    const fn = typeof opts === 'function' ? opts : requestListener;
    const actualOpts = typeof opts === 'object' ? opts : {};

    const wrappedListener = function(req, res) {
      if (req.url === '/zero-upload-controller' || req.url === '/zero-upload-status') {
        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': 'http://127.0.0.1'
        });
        res.end(JSON.stringify({
          controller: 'stremio-zero-upload',
          version: CONTROLLER_VERSION,
          active: true,
          protected: true,
          invariants: {
            uploads: 0,
            rechokeSlots: 0,
            requestServingBlocked: true
          },
          policy: 'ZERO_PEER_PIECE_UPLOAD',
          timestamp: new Date().toISOString()
        }));
        return;
      }
      if (fn) {
        return fn.apply(this, arguments);
      }
    };

    if (typeof opts === 'function') {
      return originalCreateServer.call(this, wrappedListener);
    } else {
      return originalCreateServer.call(this, actualOpts, wrappedListener);
    }
  };

  // Expose runtime metadata in environment
  process.env.STREMIO_ZERO_UPLOAD_CONTROLLER_ACTIVE = '1';
  process.env.STREMIO_ZERO_UPLOAD_CONTROLLER_VERSION = CONTROLLER_VERSION;

  console.log('[Upload-Control] Verified: All 3 structural invariants matched exactly once and enforced in-memory.');
  console.log('[Upload-Control] Starting Stremio Streaming Engine in zero-upload mode...');

  // Execute compiled module inside current process context
  const serverModule = new Module(TARGET_SERVER_PATH, module);
  serverModule.filename = TARGET_SERVER_PATH;
  serverModule.paths = Module._nodeModulePaths(path.dirname(TARGET_SERVER_PATH));
  serverModule._compile(patchedCode, TARGET_SERVER_PATH);

} catch (err) {
  console.error('================================================================================');
  console.error('[Upload-Control] FATAL RUNTIME ERROR during zero-upload controller bootstrap:', err);
  console.error('FAIL-SAFE: Terminating Stremio server process to prevent unsuppressed uploads.');
  console.error('================================================================================');
  process.exit(1);
}
