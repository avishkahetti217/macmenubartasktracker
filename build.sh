#!/bin/bash
# Builds TaskTracker.app in ./build. Pass --install to copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP="build/TaskTracker.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TaskTracker "$APP/Contents/MacOS/TaskTracker"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>TaskTracker</string>
    <key>CFBundleDisplayName</key><string>Task Tracker</string>
    <key>CFBundleIdentifier</key><string>local.tasktracker</string>
    <key>CFBundleExecutable</key><string>TaskTracker</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf /Applications/TaskTracker.app
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/TaskTracker.app"
fi
