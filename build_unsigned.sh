#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/ExternalNoxel.xcarchive"
IPA="$BUILD_DIR/ExternalNoxel-unsigned.ipa"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

command -v xcodebuild >/dev/null || { echo 'xcodebuild is required on macOS' >&2; exit 127; }

echo "=== Checking Xcode project ==="
xcodebuild -list -project "$ROOT/ExternalNoxel.xcodeproj" || {
    echo "❌ Project not found or invalid" >&2
    exit 1
}

echo "=== Building archive ==="
xcodebuild \
  -project "$ROOT/ExternalNoxel.xcodeproj" \
  -scheme ExternalNoxel \
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

APP="$ARCHIVE/Products/Applications/ExternalNoxel.app"
if [ ! -d "$APP" ]; then
    echo "❌ .app not found at $APP" >&2
    exit 1
fi

# Patches folder (optional)
PATCH_DIR="$APP/Patches"
mkdir -p "$PATCH_DIR"
for package in "$APP"/*.3105; do
    [ -e "$package" ] || continue
    mv "$package" "$PATCH_DIR/"
done

# Jangan ubah CFBundleExecutable — biarkan default
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"

cd "$BUILD_DIR"
zip -qry "$IPA" Payload
rm -rf Payload

echo "✅ IPA created: $IPA"
