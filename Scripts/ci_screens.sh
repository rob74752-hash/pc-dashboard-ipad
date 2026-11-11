#!/bin/bash
# Boots a big iPad simulator and screenshots each screen in demo mode.
# The app draws itself inside an exact 1024x768 (or 768x1024) "canvas", the size of the
# user's iPad (6th generation), so layouts are checked at the real size.
set -u
APP="build/Build/Products/Debug-iphonesimulator/PCDashboard.app"
BUNDLE="com.pcdashboard.ipad"
mkdir -p shots

RUNTIME=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r.get("isAvailable") and r["name"].startswith("iOS")]
print(sorted(rs, key=lambda r: r["version"])[-1]["identifier"])')
TYPE=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
ts = [t for t in json.load(sys.stdin)["devicetypes"] if "iPad Pro" in t["name"] and "13" in t["name"]]
print(sorted(ts, key=lambda t: t["name"])[-1]["identifier"] if ts else "")')
if [ -z "$TYPE" ]; then
  TYPE=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
ts = [t for t in json.load(sys.stdin)["devicetypes"] if t["name"].startswith("iPad")]
print(ts[-1]["identifier"])')
fi
echo "Runtime: $RUNTIME  Device: $TYPE"
date
UDID=$(xcrun simctl create "Dash iPad" "$TYPE" "$RUNTIME")
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
date

shot() {
  local name="$1"; shift
  xcrun simctl launch "$UDID" "$BUNDLE" -demo "$@" > /dev/null
  sleep "${WAIT:-7}"
  xcrun simctl io "$UDID" screenshot "shots/$name.png" > /dev/null 2>&1
  xcrun simctl terminate "$UDID" "$BUNDLE" > /dev/null 2>&1 || true
  sleep 1
}

L="-canvas 1024x768"
P="-canvas 768x1024"
# Every look: the overview and its Core page.
for S in gilded glass paper terminal reactor molten apex cyber; do
  WAIT=8 shot "$S-overview" $L -page overview -style $S
  shot "$S-core" $L -page core -style $S
done
# The other pages in a few looks.
for S in gilded reactor molten cyber apex paper; do
  shot "$S-clock" $L -page clock -style $S
done
for S in gilded glass cyber molten; do
  shot "$S-music" $L -page music -style $S
done
for S in reactor cyber apex; do
  shot "$S-performance" $L -page performance -style $S
done
shot settings $L -settings
shot settings-cyber $L -settings -style cyber
shot connect $L -connect -style reactor
shot hot $L -page core -style cyber -hot -fahrenheit
shot gilded-rose $L -page overview -style gilded -accent rose
shot reactor-ice $L -page core -style reactor -accent cyan
shot portrait-molten $P -page overview -style molten
shot portrait-core $P -page core -style reactor
date

# A short clip of the overview to check the gold shimmer and live numbers.
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "shots/overview.mp4" > /dev/null 2>&1 &
REC=$!
sleep 2
xcrun simctl launch "$UDID" "$BUNDLE" -demo $L -page core -style molten > /dev/null
sleep 8
kill -INT "$REC" 2>/dev/null; wait "$REC" 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" > /dev/null 2>&1 || true

mkdir -p shots/crashes
cp ~/Library/Logs/DiagnosticReports/PCDashboard* shots/crashes/ 2>/dev/null || true
xcrun simctl spawn "$UDID" log show --last 6m --style compact --predicate 'process == "PCDashboard" AND (messageType == error OR messageType == fault)' > shots/app-errors.log 2>/dev/null || true
ls -la shots shots/crashes
