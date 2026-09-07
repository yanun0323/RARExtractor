#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Yanun Yang (Y366CJ66L6)}"
TEAM="${DEVELOPMENT_TEAM:-Y366CJ66L6}"
PROFILE="${NOTARY_PROFILE:-RARExtractor-notary}"
ACCOUNT="${SPARKLE_ACCOUNT:-app.rarextractor}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' RARApp/Info.plist)
OUT="dist/$VERSION"
APP="DerivedDataRelease/Build/Products/Release/RARExtractor.app"
ZIP="$OUT/RARExtractor-$VERSION-macOS-arm64.zip"
mkdir -p "$OUT"
if [[ -e "$ZIP" ]]; then
    echo "Refusing to overwrite $ZIP. Move the previous output before retrying." >&2
    exit 1
fi
make test
xcodebuild -workspace RARExtractor.xcworkspace -scheme RARExtractor \
    -configuration Release -derivedDataPath DerivedDataRelease \
    CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$TEAM" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS=--timestamp build

# Sign nested Sparkle code inside-out; do not use codesign --deep for signing.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
for component in \
    "$SPARKLE/Versions/B/Autoupdate" \
    "$SPARKLE/Versions/B/Updater.app" \
    "$SPARKLE/Versions/B/XPCServices/Downloader.xpc" \
    "$SPARKLE/Versions/B/XPCServices/Installer.xpc" \
    "$SPARKLE"; do
    codesign --force --sign "$IDENTITY" --options runtime --timestamp \
        --preserve-metadata=identifier,entitlements "$component"
done
codesign --force --sign "$IDENTITY" --options runtime --timestamp \
    --preserve-metadata=identifier,entitlements "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait \
    --output-format json > "$OUT/notarization.json"
if [[ "$(plutil -extract status raw -o - "$OUT/notarization.json")" != Accepted ]]; then
    echo "Notarization failed. See $OUT/notarization.json; stopping before appcast generation." >&2
    exit 1
fi
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict "$APP"
spctl --assess --type execute --verbose=2 "$APP"
# Repackage after stapling; sign the final ZIP, not the notarization upload.
rm "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
DerivedDataRelease/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast \
    --account "$ACCOUNT" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/yanun0323/RARExtractor/releases/download/v$VERSION/" \
    --link https://github.com/yanun0323/RARExtractor "$OUT"
(cd "$OUT" && shasum -a 256 "$(basename "$ZIP")" > SHA256SUMS)
echo "Release ready in $OUT. Nothing has been uploaded to GitHub."
