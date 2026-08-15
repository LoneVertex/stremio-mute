/**
 * Stremio Mute — Engine-Level BitTorrent Upload Controller
 * 
 * Project: Stremio Mute (https://github.com/LoneVertex/stremio-mute)
 * Tagline: Mute BitTorrent peer uploads. Keep streaming.
 * Description: Application-level BitTorrent peer-upload suppression for Stremio Linux Flatpak.
 * 
 * Invariants Enforced:
 *   1. rechokeSlots = 0 (Peers remain permanently choked; zero upload slots allocated)
 *   2. EngineFS.getDefaults().uploads = 0 (Engine constructor defaults to 0 upload slots)
 *   3. wire.on("request") Neutralized (Blocks disk piece reads & wire block transmission)
 * 
 * Safety & Reliability Guarantees:
 *   - Idempotent: Single process execution guard.
 *   - Structural Compatibility Fingerprinted: Every patch requires EXACTLY 1 occurrence in server.js.
 *   - Local IPC Status: Exposes loopback /zero-upload-controller endpoint on 127.0.0.1:11470.
 *   - Fail-Closed: Aborts execution immediately with diagnostics if any structural mismatch occurs.
 *   - Zero Fallback: Never executes unmodified server.js upon patching failure.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const Module = require('module');

const CONTROLLER_NAME = 'stremio-mute';
const CONTROLLER_VERSION = '1.2.1';
const TARGET_SERVER_PATH = process.env.STREMIO_TARGET_SERVER_PATH || '/app/libexec/stremio/server.js';

// Idempotence guard
if (global.__STREMIO_MUTE_CONTROLLER_INITIALIZED__) {
  console.log(`[Stremio-Mute] Controller v${CONTROLLER_VERSION} already initialized in this process.`);
  return;
}
global.__STREMIO_MUTE_CONTROLLER_INITIALIZED__ = true;

console.log(`[Stremio-Mute] Initializing Stremio Mute v${CONTROLLER_VERSION}...`);

// Pre-flight check: Target existence
if (!fs.existsSync(TARGET_SERVER_PATH)) {
  console.error('================================================================================');
  console.error(`[Stremio-Mute] FATAL: Target Stremio server not found at: ${TARGET_SERVER_PATH}`);
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
      replacement: 'var rechokeIntervalId, rechokeSlots = 0 /* STREMIO MUTE ENFORCED */'
    },
    {
      name: 'EngineFS.getDefaults options definition',
      pattern: 'MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {',
      replacement: 'MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {\n                uploads: 0, /* STREMIO MUTE ENFORCED */'
    },
    {
      name: 'Wire piece request handling & disk read pipeline',
      pattern: 'uploadPipe.push(engine.store.read, index, (function(err, buffer) {',
      replacement: 'return cb(new Error("Peer piece upload muted by policy")); uploadPipe.push(engine.store.read, index, (function(err, buffer) { /* STREMIO MUTE ENFORCED */'
    }
  ];

  let patchedCode = rawCode;
  let appliedCount = 0;

  for (const fp of fingerprints) {
    const occurrences = patchedCode.split(fp.pattern).length - 1;
    if (occurrences !== 1) {
      console.error('================================================================================');
      console.error('[Stremio-Mute] FATAL COMPATIBILITY ERROR: Fingerprint occurrence mismatch!');
      console.error(`Fingerprint: "${fp.name}"`);
      console.error(`Expected Occurrences: 1 | Found: ${occurrences}`);
      console.error(`Controller Version: ${CONTROLLER_VERSION}`);
      console.error('Status: Stremio server code structure has changed (possibly due to an upstream update).');
      console.error('Action Required: Run "./scripts/verify.sh" to inspect compatibility.');
      console.error('FAIL-SAFE: Aborting process to prevent unmuted BitTorrent peer uploads.');
      console.error('================================================================================');
      process.exit(1);
    }

    // Apply targeted replacement
    patchedCode = patchedCode.replace(fp.pattern, fp.replacement);
    appliedCount++;
  }

  if (appliedCount !== 3) {
    console.error(`[Stremio-Mute] FATAL: Assertion failed. Expected 3 patches, applied ${appliedCount}. Aborting.`);
    process.exit(1);
  }

  // Intercept http.createServer to provide authoritative loopback status endpoint
  const originalCreateServer = http.createServer;
  http.createServer = function(opts, requestListener) {
    const fn = typeof opts === 'function' ? opts : requestListener;
    const actualOpts = typeof opts === 'object' ? opts : {};

    const wrappedListener = function(req, res) {
      if (req.url === '/zero-upload-controller' || req.url === '/mute-status' || req.url === '/zero-upload-status') {
        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': 'http://127.0.0.1'
        });
        res.end(JSON.stringify({
          project: CONTROLLER_NAME,
          version: CONTROLLER_VERSION,
          active: true,
          muted: true,
          invariants: {
            uploads: 0,
            rechokeSlots: 0,
            wireRequestBlocked: true
          },
          policy: 'MUTE_PEER_PIECE_UPLOAD'
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
  process.env.STREMIO_MUTE_ACTIVE = '1';
  process.env.STREMIO_MUTE_VERSION = CONTROLLER_VERSION;

  console.log('[Stremio-Mute] Verified: All 3 structural invariants matched exactly once and enforced in-memory.');
  console.log('[Stremio-Mute] Starting Stremio Streaming Engine in upload-muted mode...');

  // Execute compiled module inside current process context
  const serverModule = new Module(TARGET_SERVER_PATH, module);
  serverModule.filename = TARGET_SERVER_PATH;
  serverModule.paths = Module._nodeModulePaths(path.dirname(TARGET_SERVER_PATH));
  serverModule._compile(patchedCode, TARGET_SERVER_PATH);

} catch (err) {
  console.error('================================================================================');
  console.error('[Stremio-Mute] FATAL RUNTIME ERROR during controller bootstrap:', err);
  console.error('FAIL-SAFE: Terminating Stremio server process to prevent unmuted uploads.');
  console.error('================================================================================');
  process.exit(1);
}
