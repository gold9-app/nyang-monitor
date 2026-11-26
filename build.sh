#!/bin/bash
# 냥모니터 빌드: ./build.sh        -> build/NyangMonitor.app
#               ./build.sh install -> /Applications 에 복사하고 실행
set -euo pipefail
cd "$(dirname "$0")"

APP="build/NyangMonitor.app"
BIN="$APP/Contents/MacOS/NyangMonitor"
SDK="$(xcrun --show-sdk-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "컴파일 중..."
swiftc -swift-version 5 -O \
  -target arm64-apple-macos13.0 -sdk "$SDK" \
  Sources/*.swift -o "$BIN" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>냥모니터</string>
  <key>CFBundleDisplayName</key><string>냥모니터</string>
  <key>CFBundleIdentifier</key><string>com.gold9.nyangmonitor</string>
  <key>CFBundleExecutable</key><string>NyangMonitor</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep -s - "$APP" >/dev/null 2>&1

echo "아이콘 만드는 중..."
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
rm -f build/icon_1024.png
# 새로 만든 실행파일은 LaunchServices(open)로 띄워야 안전하게 실행됨
open -W -n "$APP" --args --export-icon "$PWD/build/icon_1024.png"
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2))
  sips -z $d $d build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep -s - "$APP" >/dev/null 2>&1
echo "완료: $APP"

if [[ "${1:-}" == "install" ]]; then
  pkill -x NyangMonitor 2>/dev/null || true
  rm -rf /Applications/NyangMonitor.app
  cp -R "$APP" /Applications/
  open /Applications/NyangMonitor.app
  echo "설치하고 실행했어요: /Applications/NyangMonitor.app"
fi
