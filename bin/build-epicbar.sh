#!/bin/bash
# epic-tree: build EpicBar.app, the menu bar panel listing live epics and their kickoffs.
# usage: build-epicbar.sh [destination dir, default ~/Applications]
set -eu

home=$(cd "$(dirname "$0")/.." && pwd)
dest=${1:-$HOME/Applications}
app="$dest/EpicBar.app"

mkdir -p "$app/Contents/MacOS"
swiftc -O -swift-version 6 -target "$(uname -m)-apple-macos14" \
  -o "$app/Contents/MacOS/EpicBar" "$home/app/EpicBar.swift"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>EpicBar</string>
  <key>CFBundleIdentifier</key><string>dev.epic-tree.EpicBar</string>
  <key>CFBundleName</key><string>EpicBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>EpicTreeHome</key><string>$home</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$app" >/dev/null 2>&1
echo "built $app"
