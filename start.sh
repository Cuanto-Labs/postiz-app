#!/bin/bash
# Pre-resolve Temporal Cloud hostname using OS getaddrinfo (same path as gRPC/Node.js)
# and inject into /etc/hosts so the native Rust worker transport can resolve it.
if [ -n "$TEMPORAL_ADDRESS" ]; then
  TEMPORAL_HOST="${TEMPORAL_ADDRESS%%:*}"
  TEMPORAL_IP=$(node -e "
    var dns = require('dns');
    dns.lookup('$TEMPORAL_HOST', { family: 4 }, function(err, addr) {
      if (!err && addr) { process.stdout.write(addr); }
      process.exit(0);
    });
  " 2>/dev/null)
  if [ -n "$TEMPORAL_IP" ]; then
    echo "$TEMPORAL_IP $TEMPORAL_HOST" >> /etc/hosts
    echo "[start.sh] Temporal DNS pre-resolved: $TEMPORAL_HOST -> $TEMPORAL_IP"
  else
    echo "[start.sh] WARN: Could not pre-resolve $TEMPORAL_HOST — worker may fail"
  fi
fi

node --experimental-require-module apps/backend/dist/apps/backend/src/main.js &
BACKEND_PID=$!
node --experimental-require-module apps/orchestrator/dist/apps/orchestrator/src/main.js &
ORCHESTRATOR_PID=$!
wait $BACKEND_PID $ORCHESTRATOR_PID
