#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP="build/Tiltglass.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf build
mkdir -p "$MACOS" "$RESOURCES"

xcrun -sdk macosx metal -c Sources/FoldShaders.metal -o build/FoldShaders.air
xcrun -sdk macosx metallib build/FoldShaders.air -o "$RESOURCES/default.metallib"

FRAMEWORKS=(
  -framework AppKit
  -framework SwiftUI
  -framework Metal
  -framework MetalKit
  -framework ScreenCaptureKit
  -framework IOKit
  -framework QuartzCore
  -framework ServiceManagement
)

swiftc -O -target arm64-apple-macos14.0 Sources/*.swift -o build/Tiltglass-arm64 "${FRAMEWORKS[@]}"
swiftc -O -target x86_64-apple-macos14.0 Sources/*.swift -o build/Tiltglass-x86_64 "${FRAMEWORKS[@]}"
lipo -create build/Tiltglass-arm64 build/Tiltglass-x86_64 -output "$MACOS/Tiltglass"

cp Info.plist "$CONTENTS/Info.plist"
cp Sources/FoldShaders.metal "$RESOURCES/FoldShaders.metal"
cp Resources/default.png "$RESOURCES/default.png"
cp Resources/TiltglassIcon.svg "$RESOURCES/TiltglassIcon.svg"

mkdir -p build/icon-render
qlmanage -t -s 1024 -o build/icon-render Resources/TiltglassIcon.svg >/dev/null 2>&1 || true
if [ -f build/icon-render/TiltglassIcon.svg.png ]; then
  cp build/icon-render/TiltglassIcon.svg.png "$RESOURCES/AppIcon.png"
  ICONSET="build/AppIcon.iconset"
  mkdir -p "$ICONSET"
  sips -z 16 16 "$RESOURCES/AppIcon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$RESOURCES/AppIcon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$RESOURCES/AppIcon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$RESOURCES/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$RESOURCES/AppIcon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$RESOURCES/AppIcon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$RESOURCES/AppIcon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$RESOURCES/AppIcon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$RESOURCES/AppIcon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
  cp "$RESOURCES/AppIcon.png" "$ICONSET/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
else
  cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"
  cp Resources/AppIcon.png "$RESOURCES/AppIcon.png"
fi

codesign --force --deep --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" build/Tiltglass.app.zip

echo "Built: $APP"
echo "Archive: build/Tiltglass.app.zip"
