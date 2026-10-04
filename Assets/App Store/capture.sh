#!/bin/zsh
# Captures the raw App Store screenshots from the Simulator, then frames them with compose.swift.
#
#   ./capture.sh            capture iPhone and iPad, then compose
#   ./capture.sh iPhone     capture one device, then compose
#
# The app is filled with the made-up reports from sample_report.py, and each screen is opened
# with the Debug-only `-screenshot <scene>` launch argument (see ScreenshotScene.swift).

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT="$SCRIPT_DIR/../../PowerView.xcodeproj"
BUNDLE_ID=com.tsubuzaki.PowerView
RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-27-0
DERIVED_DATA=$(mktemp -d)
trap 'rm -rf "$DERIVED_DATA"' EXIT

# Simulator device types, and the scenes to capture on each. compose.swift picks and orders them.
typeset -A DEVICE_TYPES=(
  iPhone com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro
  iPad com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB
)
typeset -A SCENES=(
  iPhone "report apps battery hourly screen network charging compare stability library"
  iPad "report apps hourly screen network charging compare library"
)
typeset -A CONTENT_SIZES=(
  iPhone large
  iPad extra-extra-large
)
DEVICES=(${@})
(( $#DEVICES )) || DEVICES=(iPhone iPad)
STATUS_TIME=$(python3 -c "from datetime import datetime; print(datetime(2026, 10, 2, 9, 41).astimezone().isoformat(timespec='milliseconds'))")

echo "Building…"
xcodebuild -project "$PROJECT" -scheme PowerView -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED_DATA" build -quiet
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/PowerView.app"

for device in $DEVICES; do
  name="PowerView Screenshots $device"
  udid=$(xcrun simctl list devices -j | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices'].get('$RUNTIME', [])
print(next((d['udid'] for d in devices if d['name'] == '$name'), ''))")
  if [[ -z $udid ]]; then
    udid=$(xcrun simctl create "$name" "${DEVICE_TYPES[$device]}" "$RUNTIME")
  fi

  echo "Capturing on $name ($udid)…"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance light
  # The iPad screenshot is shown smaller than life on the App Store, so larger text keeps it legible.
  xcrun simctl ui "$udid" content_size ${CONTENT_SIZES[$device]}
  # 9:41 on the capture day, in the Mac's time zone, which the Simulator shows.
  xcrun simctl status_bar "$udid" override --time "$STATUS_TIME" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
    --batteryState discharging --batteryLevel 100

  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"
  container=$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data)
  reports="$container/Library/Application Support/Reports"
  mkdir -p "$reports"
  python3 "$SCRIPT_DIR/sample_report.py" "$reports" >/dev/null

  # Launch once so the first capture isn't slowed by a cold start.
  xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
  sleep 5

  out="$SCRIPT_DIR/Raw/$device/en"
  rm -rf "$out"
  mkdir -p "$out"
  for scene in ${=SCENES[$device]}; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    rm -f "$container/Library/Caches/screenshot-ready"
    # The sample reports were captured in California, so show their times there.
    SIMCTL_CHILD_TZ=America/Los_Angeles xcrun simctl launch "$udid" "$BUNDLE_ID" -screenshot "$scene" >/dev/null
    # The app writes this once the screen has settled.
    for _ in {1..60}; do
      [[ -e "$container/Library/Caches/screenshot-ready" ]] && break
      sleep 0.5
    done
    [[ -e "$container/Library/Caches/screenshot-ready" ]] || { echo "  $scene didn't settle" >&2; exit 1; }
    xcrun simctl io "$udid" screenshot --type=png "$out/$scene.png" >/dev/null 2>&1
    echo "  $scene"
  done
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl status_bar "$udid" clear
done

swift "$SCRIPT_DIR/compose.swift"
