#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FidgetBall"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP_DIR="$DIST_DIR/$APP_NAME.app"
STAGE_ROOT="$(mktemp -d "/tmp/fidgetball-package.XXXXXX")"
APP_DIR="$STAGE_ROOT/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
TIMESTAMP_FLAG="--timestamp"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  TIMESTAMP_FLAG="--timestamp=none"
fi

cleanup_stage() {
  trash "$STAGE_ROOT" 2>/dev/null || true
}
trap cleanup_stage EXIT

clear_macos_metadata() {
  local path="$1"
  xattr -cr "$path" 2>/dev/null || true
  while IFS= read -r file; do
    xattr -d com.apple.FinderInfo "$file" 2>/dev/null || true
    xattr -d 'com.apple.fileprovider.fpfs#P' "$file" 2>/dev/null || true
    xattr -d com.apple.provenance "$file" 2>/dev/null || true
  done < <(find "$path" -print)
}

cd "$ROOT_DIR"
swift build -c release --product "$APP_NAME"

mkdir -p "$DIST_DIR"
trash "$DIST_APP_DIR" 2>/dev/null || true
trash "$ZIP_PATH" 2>/dev/null || true
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp -R ".build/out/Products/Release/fidget-ball_FidgetBall.bundle" "$RESOURCES_DIR/fidget-ball_FidgetBall.bundle"
cp "$ROOT_DIR/Sources/FidgetBall/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>FidgetBall</string>
  <key>CFBundleIdentifier</key>
  <string>com.unclelyhme.fidgetball</string>
  <key>CFBundleName</key>
  <string>FidgetBall</string>
  <key>CFBundleDisplayName</key>
  <string>Fidget Ball</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

clear_macos_metadata "$APP_DIR"
codesign --force --deep --options runtime "$TIMESTAMP_FLAG" --sign "$SIGN_IDENTITY" "$APP_DIR"
clear_macos_metadata "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
clear_macos_metadata "$APP_DIR"
ditto --norsrc -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "NOTARY_KEYCHAIN_PROFILE requires CODE_SIGN_IDENTITY='Developer ID Application: ...'" >&2
    exit 1
  fi

  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"

  trash "$ZIP_PATH" 2>/dev/null || true
  clear_macos_metadata "$APP_DIR"
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
  ditto --norsrc -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
fi

ditto --norsrc "$APP_DIR" "$DIST_APP_DIR"
clear_macos_metadata "$DIST_APP_DIR"
if ! codesign --verify --deep --strict --verbose=2 "$DIST_APP_DIR"; then
  echo "warning: copied app picked up metadata in dist; share the verified zip instead" >&2
fi

echo "$DIST_APP_DIR"
echo "$ZIP_PATH"
