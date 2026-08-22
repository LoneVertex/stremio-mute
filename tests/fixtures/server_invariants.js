// tests/fixtures/server_invariants.js — Behavioral invariant probe
const fs = require('fs');
const marker = process.env.STREMIO_MUTE_READ_MARKER;
const opts = { uploads: 5 };
const settings = { btMinPeersForStable: 5 };
const isPositiveInteger = (n) => typeof n === 'number' && n > 0;
let MIN_PEERS_FOR_STABLE, defaults;
const uploadPipe = { push: function(fn, idx, cb) { fn(idx, cb); } };
const engine = { store: { read: function(idx, cb) {
  if (marker) fs.writeFileSync(marker, 'disk-read-called');
  cb(null, Buffer.alloc(0));
} } };
const index = 0;
const cb = function() {};
var rechokeIntervalId, rechokeSlots = !1 === opts.uploads || 0 === opts.uploads ? 0 : +opts.uploads || 5;
MIN_PEERS_FOR_STABLE = isPositiveInteger(settings.btMinPeersForStable) ? settings.btMinPeersForStable : 5, defaults = {
  connections: 100
};
function exerciseRequestPath() {
  uploadPipe.push(engine.store.read, index, (function(err, buffer) {
    throw new Error('disk-piece callback executed');
  }));
}
try {
  exerciseRequestPath();
  if (rechokeSlots !== 0) process.exit(2);
  if (defaults.uploads !== 0) process.exit(3);
  if (marker && fs.existsSync(marker)) process.exit(4);
} catch (err) {
  process.exit(5);
}
process.exit(0);
