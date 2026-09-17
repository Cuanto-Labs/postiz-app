#!/usr/bin/env bash
# gate.sh — CuantoSocials iOS DoD gate: xcodegen + build all targets (CODE_SIGNING_ALLOWED=NO)
# + Swift Testing on ONE simulator. Repo-wide flock so parallel autopilot cards serialize;
# machine-wide sim lock (same dir as ios-suite) so at most one simulator is ever booted.
# Never boot a second sim. AUTHORS the gate only — this script is what ios-gate-green runs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/ios"

export USER="${USER:-jarvis}"
export PATH="/opt/homebrew/bin:$PATH"

SIM_NAME="${IOS_GATE_SIM:-iPhone 17 Pro Max}"
CONFIG="${IOS_GATE_CONFIG:-Debug}"
DERIVED="$ROOT/ios/.derived"
BUILD_LOG="$ROOT/ios/gate-build.log"
TEST_LOG="$ROOT/ios/gate-test.log"

log() { printf '[gate] %s\n' "$*" >&2; }
die() {
  printf '[gate] FAIL: %s\n' "$*" >&2
  exit 1
}

fail_with_log() {
  local label="$1" log_file="$2"
  echo "[gate] $label failed — last 80 lines of $log_file:" >&2
  tail -n 80 "$log_file" >&2 || true
  exit 1
}

# ---------------------------------------------------------------------------
# 1) locks — repo flock first (serializes parallel autopilot cards touching this
# repo), then the machine-wide simulator mutex (mirrors ios-suite/lib/common.sh
# sim_lock: mkdir is the atomic primitive, macOS has no flock(1)).
# ---------------------------------------------------------------------------
exec 9>>"${IOS_GATE_LOCK:-/tmp/cuanto-socials-ios-gate.lock}"
python3 -c 'import fcntl; fcntl.flock(9, fcntl.LOCK_EX)'

SIM_LOCK_DIR="${SIM_LOCK_DIR:-/tmp/ios-suite-sim.lock}"
_SIM_LOCK_HELD=0

sim_lock() {
  [ "${IOS_SIM_NO_LOCK:-0}" = "1" ] && return 0
  [ "$_SIM_LOCK_HELD" -eq 1 ] && return 0
  local waited=0 limit="${IOS_SIM_LOCK_WAIT:-1800}" holder
  while ! mkdir "$SIM_LOCK_DIR" 2>/dev/null; do
    holder="$(cat "$SIM_LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
      log "clearing stale simulator lock from dead pid $holder"
      rm -rf "$SIM_LOCK_DIR"
      continue
    fi
    if [ "$waited" -ge "$limit" ]; then
      die "another simulator run holds $SIM_LOCK_DIR (pid ${holder:-?}) after ${limit}s"
    fi
    [ "$waited" -eq 0 ] && log "waiting for the simulator lock (held by pid ${holder:-?})"
    sleep 5
    waited=$((waited + 5))
  done
  printf '%s' "$$" >"$SIM_LOCK_DIR/pid"
  printf '%s' "${IOS_SIM_LOCK_LABEL:-CuantoSocials}" >"$SIM_LOCK_DIR/label" 2>/dev/null || true
  _SIM_LOCK_HELD=1
}

sim_unlock() {
  [ "$_SIM_LOCK_HELD" -eq 1 ] || return 0
  rm -rf "$SIM_LOCK_DIR"
  _SIM_LOCK_HELD=0
}

trap sim_unlock EXIT INT TERM

sim_lock

# ---------------------------------------------------------------------------
# 2) xcodegen
# ---------------------------------------------------------------------------
log "xcodegen generate"
xcodegen generate --spec Project.yml --project . || die "xcodegen generate"

# ---------------------------------------------------------------------------
# 2b) accessibility lint — cheap, fail fast before booting a simulator.
# Scoped to the dirs already fixed this milestone; other Features/* dirs are
# owned by other cards/lanes and not yet clean — widen A11Y_SCOPE as those
# land instead of scanning the whole tree here.
# ---------------------------------------------------------------------------
log "a11y-lint.sh"
bash "$ROOT/ios/scripts/a11y-lint.sh" \
  "$ROOT/ios/App/Features/Notifications" \
  "$ROOT/ios/App/Features/AI" \
  "$ROOT/ios/App/Features/Analytics" \
  "$ROOT/ios/App/Features/Settings" \
  "$ROOT/ios/App/Features/Push" \
  || die "a11y-lint"

# ---------------------------------------------------------------------------
# 3) resolve UDID for SIM_NAME (create if missing), single booted sim
# ---------------------------------------------------------------------------
UDID="$(xcrun simctl list devices -j | python3 -c "
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)['devices']
for runtime in sorted(data.keys(), reverse=True):
    for d in data[runtime]:
        if d.get('name') == name:
            print(d['udid'])
            sys.exit()
" "$SIM_NAME")"

if [ -z "$UDID" ]; then
  DEVICE_TYPE_ID="$(xcrun simctl list devicetypes -j | python3 -c "
import json, sys
name = sys.argv[1]
for dt in json.load(sys.stdin)['devicetypes']:
    if dt.get('name') == name:
        print(dt['identifier'])
        sys.exit()
" "$SIM_NAME")"
  [ -n "$DEVICE_TYPE_ID" ] || die "no simulator named '$SIM_NAME' and no matching device type"
  RUNTIME_ID="$(xcrun simctl list runtimes -j | python3 -c "
import json, sys
runtimes = [r for r in json.load(sys.stdin)['runtimes'] if r.get('isAvailable') and 'iOS' in r.get('name', '')]
runtimes.sort(key=lambda r: r.get('version', ''))
print(runtimes[-1]['identifier'] if runtimes else '')
")"
  [ -n "$RUNTIME_ID" ] || die "no installed iOS simulator runtime found"
  log "creating simulator '$SIM_NAME' (no existing device with this name)"
  UDID="$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE_ID" "$RUNTIME_ID")" || die "simctl create failed"
fi

# never boot a second sim — shut down every other booted device first
while read -r other; do
  [ -z "$other" ] && continue
  [ "$other" = "$UDID" ] && continue
  log "shutting down other booted simulator $other (one sim at a time)"
  xcrun simctl shutdown "$other" >/dev/null 2>&1 || true
done <<<"$(xcrun simctl list devices -j | python3 -c "
import json, sys
for v in json.load(sys.stdin)['devices'].values():
    for x in v:
        if x.get('state') == 'Booted':
            print(x['udid'])
")"

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 4) build all targets, signing disabled
# ---------------------------------------------------------------------------
log "xcodebuild build ($CONFIG)"
xcodebuild build \
  -project CuantoSocials.xcodeproj \
  -scheme CuantoSocials \
  -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -skipPackagePluginValidation \
  -quiet >"$BUILD_LOG" 2>&1 || fail_with_log "build" "$BUILD_LOG"

# ---------------------------------------------------------------------------
# 5) Swift Testing — one sim, serialized
# ---------------------------------------------------------------------------
log "xcodebuild test ($CONFIG)"
xcodebuild test \
  -project CuantoSocials.xcodeproj \
  -scheme CuantoSocials \
  -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -skipPackagePluginValidation \
  -only-testing:CuantoSocialsTests \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -quiet >"$TEST_LOG" 2>&1 || fail_with_log "test" "$TEST_LOG"

# ---------------------------------------------------------------------------
# 6) design gate — Dynamic Type matrix (opt-in via IOS_GATE_DESIGN=1). Off by
# default so the everyday gate stays fast/unchanged; ios-gate-green / release
# runs turn it on. Pinned to the single sim booted above via --devices
# "$SIM_NAME" — never lets ios-layout-check's own smallest+largest default
# boot a second simulator. This script already holds the machine-wide sim
# lock from step 1 for its whole run, so the child ios-layout-check call
# opts out of re-acquiring it (IOS_SIM_NO_LOCK=1) instead of deadlocking
# against itself; it still only ever runs serialized under this gate's lock.
# ---------------------------------------------------------------------------
if [ "${IOS_GATE_DESIGN:-0}" = "1" ]; then
  IOS_SUITE_DIR="${IOS_SUITE_DIR:-$HOME/coding/ios-suite}"
  [ -x "$IOS_SUITE_DIR/bin/ios-layout-check" ] \
    || die "ios-layout-check not found at $IOS_SUITE_DIR/bin (set IOS_SUITE_DIR)"
  export PATH="$IOS_SUITE_DIR/bin:$PATH"
  log "ios-layout-check --design ($SIM_NAME only)"
  IOS_SIM_NO_LOCK=1 ios-layout-check --design --devices "$SIM_NAME" --app "$ROOT/ios" \
    || die "ios-layout-check --design"
fi

log "gate passed"
