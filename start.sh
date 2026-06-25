#!/bin/bash
# Temporal Cloud DNS pre-resolution.
# The native Rust worker transport (tonic) resolves DNS synchronously via getaddrinfo.
# Railway container's OS resolver fails for Temporal Cloud hostnames.
# Fix: use DNS-over-HTTPS (Cloudflare 1.1.1.1) — bypasses the broken OS resolver.
# Injecting into /etc/hosts makes getaddrinfo succeed for both Rust and Node.js.
if [ -n "$TEMPORAL_ADDRESS" ]; then
  TEMPORAL_HOST="${TEMPORAL_ADDRESS%%:*}"

  # 1. Try Cloudflare DoH
  TEMPORAL_IP=$(curl -sf --max-time 10 \
    "https://1.1.1.1/dns-query?name=${TEMPORAL_HOST}&type=A" \
    -H "Accept: application/dns-json" 2>/dev/null \
    | node -e "
var d='';
process.stdin.on('data',function(c){d+=c});
process.stdin.on('end',function(){
  try{
    var j=JSON.parse(d);
    var ans=(j.Answer||[]).filter(function(a){return a.type===1});
    if(ans.length){process.stdout.write(ans[0].data);}
  }catch(e){}
  process.exit(0);
});")

  # 2. Fallback: Google DoH
  if [ -z "$TEMPORAL_IP" ]; then
    TEMPORAL_IP=$(curl -sf --max-time 10 \
      "https://8.8.8.8/resolve?name=${TEMPORAL_HOST}&type=A" \
      -H "Accept: application/dns-json" 2>/dev/null \
      | node -e "
var d='';
process.stdin.on('data',function(c){d+=c});
process.stdin.on('end',function(){
  try{
    var j=JSON.parse(d);
    var ans=(j.Answer||[]).filter(function(a){return a.type===1});
    if(ans.length){process.stdout.write(ans[0].data);}
  }catch(e){}
  process.exit(0);
});")
  fi

  if [ -n "$TEMPORAL_IP" ]; then
    echo "$TEMPORAL_IP  $TEMPORAL_HOST" >> /etc/hosts
    echo "[start.sh] Temporal DNS pre-resolved: $TEMPORAL_HOST -> $TEMPORAL_IP"
  else
    echo "[start.sh] WARN: Could not resolve $TEMPORAL_HOST via DoH — worker may fail"
  fi
fi

node --experimental-require-module apps/backend/dist/apps/backend/src/main.js &
BACKEND_PID=$!
node --experimental-require-module apps/orchestrator/dist/apps/orchestrator/src/main.js &
ORCHESTRATOR_PID=$!
wait $BACKEND_PID $ORCHESTRATOR_PID
