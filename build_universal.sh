#!/usr/bin/env bash
#
# build_universal.sh
# Build External Nixx IPA for iOS 17–27 (opa334 + BadKernel dual-backend).
#

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/NixxTime.xcarchive"
IPA="$BUILD_DIR/External-Nixx-Universal.ipa"
PROJ="$ROOT/ExternalNoelx.xcodeproj"
HEADER_SHIM="$ROOT/ExternalNoelx/kexploit/include"
BADKERNEL_PATH="$ROOT/ExternalNoelx/BadKernel"

echo "═══════════════════════════════════════════════════════════"
echo "  External Nixx — Universal Build (iOS 17–27)"
echo "═══════════════════════════════════════════════════════════"

# ─── 1. Verify private SDK shim ─────────────────────────────
if [ ! -f "$HEADER_SHIM/sys/fileport.h" ]; then
    echo "❌ Missing $HEADER_SHIM/sys/fileport.h"
    exit 1
fi

# ─── 2. Verify BadKernel files ──────────────────────────────
echo "▶ Checking BadKernel files..."
if [ -f "$ROOT/ExternalNoelx/BadKernel.m" ]; then
    echo "  ✅ BadKernel.m exists ($(wc -l < "$ROOT/ExternalNoelx/BadKernel.m") lines)"
else
    echo "  ❌ BadKernel.m NOT FOUND"
    exit 1
fi

if [ -f "$ROOT/ExternalNoelx/BadKernel.h" ]; then
    echo "  ✅ BadKernel.h exists ($(wc -l < "$ROOT/ExternalNoelx/BadKernel.h") lines)"
else
    echo "  ❌ BadKernel.h NOT FOUND"
    exit 1
fi

if [ -d "$BADKERNEL_PATH" ]; then
    echo "  ✅ BadKernel/ folder exists"
    ls -la "$BADKERNEL_PATH/" | tail -n +2 | awk '{print "    " $NF}'
fi

# ─── 3. Clean ───────────────────────────────────────────────
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ─── 4. Prereqs ─────────────────────────────────────────────
command -v xcodebuild >/dev/null || { echo "❌ xcodebuild not found" >&2; exit 127; }
[ -d "$PROJ" ] || { echo "❌ Xcode project not found at $PROJ" >&2; exit 1; }

# ─── 5. Verify project ──────────────────────────────────────
echo "▶ Project: $PROJ"
xcodebuild -list -project "$PROJ"

# ─── 6. Build archive ───────────────────────────────────────
echo "▶ Building archive (scheme: NixxTime)…"

# Build header search paths (include BadKernel folder + include subfolder)
SEARCH_PATHS="\$(inherited) $HEADER_SHIM $BADKERNEL_PATH $BADKERNEL_PATH/include"

# Framework buat BadKernel (IOSurface, libresolv, libz, libdl)
OTHER_LDFLAGS_VALUE="-framework IOSurface -framework Foundation -lresolv -lz -ldl"

echo "  HEADER_SEARCH_PATHS = $SEARCH_PATHS"
echo "  OTHER_LDFLAGS = $OTHER_LDFLAGS_VALUE"
echo ""

xcodebuild \
    -project "$PROJ" \
    -scheme NixxTime \
    -configuration Release \
    -sdk iphoneos \
    -archivePath "$ARCHIVE" \
    HEADER_SEARCH_PATHS="$SEARCH_PATHS" \
    OTHER_LDFLAGS="$OTHER_LDFLAGS_VALUE" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' \
    clean archive

[ -d "$ARCHIVE" ] || { echo "❌ Archive not created" >&2; exit 1; }

APP="$ARCHIVE/Products/Applications/NixxTime.app"
[ -d "$APP" ] || { echo "❌ .app not found at $APP" >&2; exit 1; }

# ─── 7. Package IPA ─────────────────────────────────────────
echo "▶ Packaging IPA…"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"

# Strip signing artifacts (eSign will inject its own)
rm -f "$BUILD_DIR/Payload/NixxTime.app/embedded.mobileprovision" 2>/dev/null || true
rm -rf "$BUILD_DIR/Payload/NixxTime.app/_CodeSignature" 2>/dev/null || true

cd "$BUILD_DIR"
zip -qry "$IPA" Payload
rm -rf Payload

# ─── 8. Done ────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ IPA: $IPA"
echo "  📦 Size: $(du -h "$IPA" | cut -f1)"
echo "═══════════════════════════════════════════════════════════"
