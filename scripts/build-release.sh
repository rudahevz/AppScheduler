#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# App Scheduler — Local build, sign, notarize, and package script
#
# Usage:
#   ./scripts/build-release.sh
#
# Prerequisites:
#   • Xcode 15+ installed
#   • Developer ID Application certificate in your Keychain
#   • Set the four variables in the CONFIG section below, or export them
#     as environment variables before running this script
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── CONFIG — edit these or export as env vars ─────────────────────────────────
TEAM_ID="${TEAM_ID:-YOUR_TEAM_ID}"                   # 10-char Apple Team ID
BUNDLE_ID="${BUNDLE_ID:-com.yourcompany.appscheduler}"
APPLE_ID="${APPLE_ID:-you@example.com}"              # for notarytool
APP_PASSWORD="${APP_PASSWORD:-}"                     # app-specific password
# ─────────────────────────────────────────────────────────────────────────────

APP_NAME="App Scheduler"
SCHEME="AppScheduler"
PROJECT="swift-app/AppScheduler.xcodeproj"
BUILD_DIR="$(pwd)/build"
ARCHIVE="$BUILD_DIR/AppScheduler.xcarchive"
EXPORT="$BUILD_DIR/export"
DMG="$BUILD_DIR/AppScheduler.dmg"

echo "╔══════════════════════════════════════╗"
echo "║   App Scheduler — Release Builder    ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Validate config
if [[ "$TEAM_ID" == "YOUR_TEAM_ID" ]]; then
  echo "❌  Set TEAM_ID before running. Export it or edit this script."
  exit 1
fi
if [[ -z "$APP_PASSWORD" ]]; then
  echo "❌  Set APP_PASSWORD (app-specific password from appleid.apple.com)"
  exit 1
fi

# Clean build dir
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ── 1. Archive ────────────────────────────────────────────────────────────────
echo "▶  Archiving…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme  "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  -quiet
echo "   ✓ Archive complete"

# ── 2. Export ─────────────────────────────────────────────────────────────────
echo "▶  Exporting…"
cat > /tmp/ExportOptions.plist << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath  "$EXPORT" \
  -exportOptionsPlist /tmp/ExportOptions.plist \
  -quiet
echo "   ✓ Export complete"

# ── 3. Verify signature ───────────────────────────────────────────────────────
echo "▶  Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$EXPORT/$APP_NAME.app"
spctl --assess --type exec --verbose "$EXPORT/$APP_NAME.app" || true
echo "   ✓ Signature valid"

# ── 4. Notarize .app ─────────────────────────────────────────────────────────
echo "▶  Notarizing app (this takes 1–5 minutes)…"
ditto -c -k --keepParent "$EXPORT/$APP_NAME.app" /tmp/app-notarize.zip
xcrun notarytool submit /tmp/app-notarize.zip \
  --apple-id  "$APPLE_ID" \
  --password  "$APP_PASSWORD" \
  --team-id   "$TEAM_ID" \
  --wait
xcrun stapler staple "$EXPORT/$APP_NAME.app"
echo "   ✓ Notarization complete"

# ── 5. Create DMG ────────────────────────────────────────────────────────────
echo "▶  Creating DMG…"
if ! command -v create-dmg &>/dev/null; then
  echo "   Installing create-dmg…"
  brew install create-dmg
fi

# Remove old DMG if re-running
rm -f "$DMG"

create-dmg \
  --volname      "$APP_NAME" \
  --window-size  540 380 \
  --icon-size    128 \
  --icon         "$APP_NAME.app" 140 190 \
  --app-drop-link 400 190 \
  --hide-extension "$APP_NAME.app" \
  "$DMG" \
  "$EXPORT/$APP_NAME.app"

# Sign the DMG
codesign --sign "Developer ID Application" \
  --timestamp \
  "$DMG"
echo "   ✓ DMG created"

# ── 6. Notarize DMG ──────────────────────────────────────────────────────────
echo "▶  Notarizing DMG…"
xcrun notarytool submit "$DMG" \
  --apple-id  "$APPLE_ID" \
  --password  "$APP_PASSWORD" \
  --team-id   "$TEAM_ID" \
  --wait
xcrun stapler staple "$DMG"
echo "   ✓ DMG notarized"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ✅  Release build complete!            ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "   DMG: $DMG"
echo ""
echo "   Next steps:"
echo "   1. Test the DMG on a clean Mac (or VM)"
echo "   2. Upload to GitHub Releases, your website, or Gumroad"
echo ""
