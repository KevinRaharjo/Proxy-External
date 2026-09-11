#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/OGIOS.xcarchive"
IPA="$BUILD_DIR/External-Nixx.ipa"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

command -v xcodebuild >/dev/null || { echo '❌ xcodebuild not found' >&2; exit 127; }

echo "=== Checking Xcode project ==="
xcodebuild -list -project "$ROOT/ExternalNoelx.xcodeproj" || {
    echo "❌ Project not found or invalid" >&2
    exit 1
}

echo "=== Building archive ==="
xcodebuild \
  -project "$ROOT/ExternalNoelx.xcodeproj" \
  -scheme OGIOS \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  clean archive

if [ ! -d "$ARCHIVE" ]; then
    echo "❌ Archive not created" >&2
    exit 1
fi

APP="$ARCHIVE/Products/Applications/OGIOS.app"
if [ ! -d "$APP" ]; then
    echo "❌ .app not found at $APP" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"

cd "$BUILD_DIR"
zip -qry "$IPA" Payload
rm -rf Payload

echo "✅ IPA created: $IPA"
