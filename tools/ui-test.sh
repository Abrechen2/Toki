#!/usr/bin/env bash
# Runs the UI tests on a simulator that is prepared the way they expect.
#
# The location tests (OfficeSetup, StaleStay) need location access for Toki and a
# simulated location far from the test office (48.07,11.68). Without both, four of
# them fail although the app is fine. This script grants the permission, sets the
# location and runs the suite serially, as the tests require.
#
# Usage (on a Mac with Xcode, from the repository root):
#   tools/ui-test.sh                          # whole UI suite
#   tools/ui-test.sh -only-testing:TokiUITests/StaleStayUITests
# Environment:
#   TOKI_SIM=<simulator id>   use this simulator instead of the first available iPhone
#   TOKI_SIM_ERASE=1          erase the simulator first (clean state)
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID=com.denniswittke.Toki
# Berlin: far outside the 150 m test office used by StaleStayUITests.
LOCATION=52.5200,13.4050

sim="${TOKI_SIM:-}"
if [ -z "$sim" ]; then
  sim=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if "iOS" not in runtime:
        continue
    for d in devices[runtime]:
        if d["name"].startswith("iPhone"):
            print(d["udid"]); sys.exit()
sys.exit("no available iPhone simulator")')
fi
echo "Simulator: $sim"

if [ "${TOKI_SIM_ERASE:-0}" = 1 ]; then
  xcrun simctl shutdown "$sim" 2>/dev/null || true
  xcrun simctl erase "$sim"
fi
xcrun simctl boot "$sim" 2>/dev/null || true   # already booted is fine
xcrun simctl bootstatus "$sim" -b >/dev/null

# The grant works before the app is installed and survives reinstalling it.
xcrun simctl privacy "$sim" grant location-always "$BUNDLE_ID"
xcrun simctl location "$sim" set "$LOCATION"

args=("$@")
[ ${#args[@]} -eq 0 ] && args=(-only-testing:TokiUITests)

xcodebuild test -project Toki.xcodeproj -scheme Toki \
  -destination "id=$sim" -parallel-testing-enabled NO "${args[@]}"
