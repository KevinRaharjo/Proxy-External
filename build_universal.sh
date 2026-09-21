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

# ─── 1. BadKernel (clone + copy into project tree) ──────────
if [ -f "$ROOT/setup_badkernel.sh" ]; then
    echo "▶ Running setup_badkernel.sh"
    bash "$ROOT/setup_badkernel.sh" || {
        echo "⚠️  setup_badkernel.sh failed — BadKernel stub will be used"
    }
else
    echo "⚠️  setup_badkernel.sh not found — BadKernel stub will be used"
fi

# ─── 2. Verify private SDK shim ─────────────────────────────
if [ ! -f "$HEADER_SHIM/sys/fileport.h" ]; then
    echo "❌ Missing $HEADER_SHIM/sys/fileport.h"
    echo "   Run the setup command from README before building."
    exit 1
fi

# ─── 3. Verify BadKernel files ──────────────────────────────
echo "▶ Checking BadKernel files..."
if [ -f "$ROOT/ExternalNoelx/BadKernel.m" ]; then
    echo "  ✅ BadKernel.m exists"
else
    echo "  ⚠️  BadKernel.m not found"
fi

if [ -f "$ROOT/ExternalNoelx/BadKernel.h" ]; then
    echo "  ✅ BadKernel.h exists"
else
    echo "  ⚠️  BadKernel.h not found"
fi

# ─── 4. Clean ───────────────────────────────────────────────
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ─── 5. Prereqs ─────────────────────────────────────────────
command -v xcodebuild >/dev/null || { echo "❌ xcodebuild not found" >&2; exit 127; }
[ -d "$PROJ" ] || { echo "❌ Xcode project not found at $PROJ" >&2; exit 1; }

# ─── 6. Verify project ──────────────────────────────────────
echo "▶ Project: $PROJ"
xcodebuild -list -project "$PROJ"

# ─── 7. Build archive ───────────────────────────────────────
echo "▶ Building archive (scheme: NixxTime)…"

# Build header search paths
SEARCH_PATHS="\$(inherited) $HEADER_SHIM $BADKERNEL_PATH $BADKERNEL_PATH/include"

# Framework yang dibutuhin BadKernel
OTHER_LDFLAGS_VALUE="-framework IOSurface -framework Foundation -lresolv -lz -ldl"

echo "  HEADER_SEARCH_PATHS: $SEARCH_PATHS"
echo "  OTHER_LDFLAGS: $OTHER_LDFLAGS_VALUE"

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

# ─── 8. Package IPA ─────────────────────────────────────────
echo "▶ Packaging IPA…"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"

# Strip signing artifacts (eSign will inject its own)
rm -f "$BUILD_DIR/Payload/NixxTime.app/embedded.mobileprovision" 2>/dev/null || true
rm -rf "$BUILD_DIR/Payload/NixxTime.app/_CodeSignature" 2>/dev/null || true

cd "$BUILD_DIR"
zip -qry "$IPA" Payload
rm -rf Payload

# ─── 9. Done ────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ IPA: $IPA"
echo "  📦 Size: $(du -h "$IPA" | cut -f1)"
echo "═══════════════════════════════════════════════════════════"
