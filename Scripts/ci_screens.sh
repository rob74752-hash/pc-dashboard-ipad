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
UDID=$(xcrun simctl create "Dash iPad" "$TYPE" "$RUNTIME")
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"

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
WAIT=9 shot overview $L -page overview
shot performance $L -page performance
shot music $L -page music
shot clock $L -page clock
shot connect $L -connect
shot settings $L -settings
shot overview-portrait $P -page overview
shot music-portrait $P -page music
shot performance-portrait $P -page performance
shot hot $L -page overview -hot -fahrenheit
shot nomusic $L -page overview -nomusic
shot offline $L -page clock -offline

# The other styles and colours
shot glass-overview $L -page overview -style glass -accent amethyst
shot glass-music $L -page music -style glass -accent amethyst
shot glass-performance $L -page performance -style glass -accent amethyst
shot paper-overview $L -page overview -style paper -accent copper
shot paper-music $L -page music -style paper -accent copper
shot paper-clock $L -page clock -style paper -accent copper
shot paper-performance $L -page performance -style paper -accent copper
shot terminal-overview $L -page overview -style terminal -accent sapphire
shot terminal-music $L -page music -style terminal -accent sapphire
shot terminal-clock $L -page clock -style terminal -accent sapphire
shot gilded-platinum $L -page overview -accent platinum
shot gilded-rose-music $L -page music -accent rose
shot settings-paper $L -settings -style paper -accent copper
shot glass-portrait $P -page overview -style glass -accent amethyst

# A short clip of the overview to check the gold shimmer and live numbers.
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "shots/overview.mp4" > /dev/null 2>&1 &
REC=$!
sleep 2
xcrun simctl launch "$UDID" "$BUNDLE" -demo $L -page overview > /dev/null
sleep 10
kill -INT "$REC" 2>/dev/null; wait "$REC" 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" > /dev/null 2>&1 || true

mkdir -p shots/crashes
cp ~/Library/Logs/DiagnosticReports/PCDashboard* shots/crashes/ 2>/dev/null || true
xcrun simctl spawn "$UDID" log show --last 6m --style compact --predicate 'process == "PCDashboard" AND (messageType == error OR messageType == fault)' > shots/app-errors.log 2>/dev/null || true
ls -la shots shots/crashes
