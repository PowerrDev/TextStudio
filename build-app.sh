#!/bin/zsh
# Builds a release binary and wraps it in TextStudio.app
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/TextStudio"

APP="TextStudio.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TextStudio"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>TextStudio</string>
    <key>CFBundleDisplayName</key><string>TextStudio</string>
    <key>CFBundleIdentifier</key><string>local.textstudio</string>
    <key>CFBundleExecutable</key><string>TextStudio</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $(pwd)/$APP"

# ./build-app.sh --install  → replace /Applications/TextStudio.app
if [[ "${1:-}" == "--install" ]]; then
    pkill -f "/Applications/$APP/Contents/MacOS/TextStudio" 2>/dev/null || true
    rm -rf "/Applications/$APP"
    cp -R "$APP" /Applications/
    touch "/Applications/$APP"   # nudge Finder/Dock to refresh the icon
    echo "Installed /Applications/$APP"
fi
