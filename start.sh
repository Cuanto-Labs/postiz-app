#!/bin/bash
# Pre-resolve Temporal Cloud hostname via Node.js DNS (native Rust DNS fails in Railway containers)
# and inject into /etc/hosts so the worker's native transport can resolve it.
if [ -n "$TEMPORAL_ADDRESS" ]; then
  TEMPORAL_HOST="${TEMPORAL_ADDRESS%%:*}"
  TEMPORAL_IP=$(node -e "
    require('dns').resolve4('$TEMPORAL_HOST', function(err, addrs) {
      if (!err && addrs && addrs.length) { process.stdout.write(addrs[0]); }
      process.exit(0);
    });
  " 2>/dev/null)
  if [ -n "$TEMPORAL_IP" ]; then
    echo "$TEMPORAL_IP $TEMPORAL_HOST" >> /etc/hosts
    echo "[start.sh] Temporal DNS pre-resolved: $TEMPORAL_HOST -> $TEMPORAL_IP"
  else
    echo "[start.sh] WARN: Could not pre-resolve $TEMPORAL_HOST"
  fi
fi

node --experimental-require-module apps/backend/dist/apps/backend/src/main.js &
BACKEND_PID=$!
node --experimental-require-module apps/orchestrator/dist/apps/orchestrator/src/main.js &
ORCHESTRATOR_PID=$!
wait $BACKEND_PID $ORCHESTRATOR_PID
