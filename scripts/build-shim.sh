#!/usr/bin/env bash
#
# build-shim.sh - Build, sign, and install VivaldiShim.app.
#
# Compiles the Swift source, assembles the bundle, signs it ad-hoc, installs it
# to /Applications, and registers it with LaunchServices.
#
# Usage:
#   ./build-shim.sh

set -euo pipefail

APP_NAME="VivaldiShim"
BUNDLE_ID="net.evokateur.vivaldi-shim"
VERSION="0.1.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"
INSTALLED="/Applications/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

assemble() {
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS"
  swiftc -O -o "$APP/Contents/MacOS/$APP_NAME" "$ROOT/src/main.swift"
  write_plist
  codesign --force --sign - "$APP"
}

write_plist() {
  cat >"$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>Web URL</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>http</string>
        <string>https</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST
}

install_bundle() {
  rm -rf "$INSTALLED"
  cp -R "$APP" "$INSTALLED"
  "$LSREGISTER" -f "$INSTALLED"
}

main() {
  assemble
  install_bundle
  echo "Installed $INSTALLED"
}

main
