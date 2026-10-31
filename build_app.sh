#!/bin/zsh
# Builds MultiClip.app (Release).
#   ./build_app.sh            build only  -> build/MultiClip.app
#   ./build_app.sh --install  build, copy to ~/Applications and launch
set -euo pipefail
cd "${0:A:h}"

APP_NAME="MultiClip"
BUILD="build"
DEST="$HOME/Applications/$APP_NAME.app"
ICONSET="MultiClip/Resources/Assets.xcassets/AppIcon.appiconset"

# Render the icon into the asset catalog once.
if [[ ! -f "$ICONSET/icon_512x512@2x.png" ]]; then
  echo "Rendering icon…"
  mkdir -p "$BUILD"
  swift scripts/make_icon.swift "$BUILD/icon_1024.png"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$BUILD/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$BUILD/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  cat > "$ICONSET/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16",   "filename" : "icon_16x16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16",   "filename" : "icon_16x16@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32",   "filename" : "icon_32x32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32",   "filename" : "icon_32x32@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128x128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_128x128@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256x256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_256x256@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512x512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_512x512@2x.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
fi

echo "Building…"
xcodebuild -project MultiClip.xcodeproj -scheme MultiClip -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$BUILD/DerivedData" -quiet build

rm -rf "$BUILD/$APP_NAME.app"
cp -R "$BUILD/DerivedData/Build/Products/Release/$APP_NAME.app" "$BUILD/$APP_NAME.app"

if [[ "${1:-}" == "--install" ]]; then
  osascript -e "tell application id \"com.multiclip.app\" to quit" 2>/dev/null || true
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 1
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  cp -R "$BUILD/$APP_NAME.app" "$DEST"
  open "$DEST"
  echo "Installed and launched $DEST"
else
  echo "Built $BUILD/$APP_NAME.app"
fi
