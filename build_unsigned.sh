#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/ExternalNoelx.xcarchive"   # <-- tanpa spasi
IPA="$BUILD_DIR/ExternalNoelx-unsigned.ipa"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

command -v xcodebuild >/dev/null || { echo 'xcodebuild not found' >&2; exit 127; }

# Cek dulu apakah project & scheme tersedia
echo "=== Checking Xcode project ==="
xcodebuild -list -project "$ROOT/ExternalNoelx.xcodeproj" || {
    echo "❌ Project not found or invalid" >&2
    exit 1
}

echo "=== Building archive ==="
xcodebuild \
  -project "$ROOT/ExternalNoelx.xcodeproj" \
  -scheme ExternalNoelx \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  clean archive

# Pastikan archive berhasil dibuat
if [ ! -d "$ARCHIVE" ]; then
    echo "❌ Archive not created" >&2
    exit 1
fi

APP="$ARCHIVE/Products/Applications/ExternalNoelx.app"
if [ ! -d "$APP" ]; then
    echo "❌ .app not found at $APP" >&2
    exit 1
fi

# PATCH_DIR (opsional, tetap jalanin)
PATCH_DIR="$APP/Patches"
mkdir -p "$PATCH_DIR"
for package in "$APP"/*.3105; do
    [ -e "$package" ] || continue
    mv "$package" "$PATCH_DIR/"
done

# HAPUS baris PlistBuddy yang ngubah CFBundleExecutable — gak perlu!
# /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable OGIOS" "$APP/Info.plist" || true
# /usr/libexec/PlistBuddy -c "Set :CFBundlePackageType APPL" "$APP/Info.plist" || true

mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"

cd "$BUILD_DIR"
zip -qry "$IPA" Payload
rm -rf Payload

echo "✅ IPA created: $IPA"
