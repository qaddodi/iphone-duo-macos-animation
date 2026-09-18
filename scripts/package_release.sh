#!/bin/bash
set -euo pipefail

APP_PATH="${1:-build/Tiltglass.app}"
OUTPUT_PATH="${2:-build/Tiltglass.app.zip}"
IDENTITY="${DEVELOPER_ID_APPLICATION:--}"

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

codesign --force --deep --options runtime --sign "$IDENTITY" "$APP_PATH"

if [ "$IDENTITY" != "-" ]; then
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT_PATH"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit "$OUTPUT_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  rm -f "$OUTPUT_PATH"
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT_PATH"
fi

echo "$OUTPUT_PATH"
