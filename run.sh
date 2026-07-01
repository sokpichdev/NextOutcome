#!/bin/bash
#
# run.sh — build NextOutcome, boot the simulator, install, and launch.
# Usage: ./run.sh            (defaults to iPhone 17 Pro Max)
#        ./run.sh "iPhone 16"
#
set -euo pipefail

# --- config -----------------------------------------------------------------
PROJECT="NextOutcome/NextOutcome.xcodeproj"
SCHEME="NextOutcome"
BUNDLE_ID="com.SokPich.NextOutcome"
SIMULATOR="${1:-iPhone 17 Pro Max}"
CONFIG="Debug"

# Run from the repo root regardless of where the script is invoked from.
cd "$(dirname "$0")"

echo "▸ Building $SCHEME for '$SIMULATOR'…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -derivedDataPath build/DerivedData \
  build

echo "▸ Booting simulator…"
open -a Simulator
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true   # already-booted is fine

# Locate the freshly built .app (prefer our own DerivedData path).
APP=$(find build/DerivedData -name "$SCHEME.app" -path "*Debug-iphonesimulator*" | head -1)
if [ -z "$APP" ]; then
  APP=$(find ~/Library/Developer/Xcode/DerivedData -name "$SCHEME.app" -path "*Debug-iphonesimulator*" | head -1)
fi
if [ -z "$APP" ]; then
  echo "✗ Could not find $SCHEME.app — did the build succeed?" >&2
  exit 1
fi
echo "▸ Installing $APP"

xcrun simctl install booted "$APP"
xcrun simctl launch booted "$BUNDLE_ID"

echo "✓ Launched $BUNDLE_ID on '$SIMULATOR'."
