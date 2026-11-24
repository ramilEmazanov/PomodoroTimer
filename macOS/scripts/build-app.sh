#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
if [[ "$configuration" != "debug" && "$configuration" != "release" ]]; then
  echo "Usage: $0 [debug|release]" >&2
  exit 1
fi
swift build -c "$configuration"
binary_directory="$(swift build -c "$configuration" --show-bin-path)"
app="$PWD/build/Focus.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_directory/Focus" "$app/Contents/MacOS/Focus"
cp Info.plist "$app/Contents/Info.plist"
# Reuse the existing app artwork; no generated icon assets are checked in.
icon_source="../public/favicon.png"
if [[ -f "$icon_source" ]]; then
  iconset="$PWD/build/AppIcon.iconset"
  mkdir -p "$iconset"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - "$app"
echo "Built: $app"
