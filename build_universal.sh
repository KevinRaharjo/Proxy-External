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

echo "═══════════════════════════════════════════════════════════"
echo "  External Nixx — Universal Build (iOS 17–27)"
echo "═══════════════════════════════════════════════════════════"

# ─── 1. BadKernel (clone + copy into project tree) ──────────
if [ -f "$ROOT/setup_badkernel.sh" ]; then
    bash "$ROOT/setup_badkernel.sh" || true
fi

# ─── 2. Clean ───────────────────────────────────────────────
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ─── 3. Prereqs ─────────────────────────────────────────────
command -v xcodebuild >/dev/null || { echo "❌ xcodebuild not found" >&2; exit 127; }
[ -d "$PROJ" ] || { echo "❌ Xcode project not found at $PROJ" >&2; exit 1; }

# ─── 4. Verify project ──────────────────────────────────────
echo "▶ Project: $PROJ"
xcodebuild -list -project "$PROJ"

# ─── 5. Build archive ───────────────────────────────────────
echo "▶ Building archive (scheme: NixxTime)…"
xcodebuild \
    -project "$PROJ" \
    -scheme NixxTime \
    -configuration Release \
    -sdk iphoneos \
    -archivePath "$ARCHIVE" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' \
    clean archive

[ -d "$ARCHIVE" ] || { echo "❌ Archive not created" >&2; exit 1; }

APP="$ARCHIVE/Products/Applications/NixxTime.app"
[ -d "$APP" ] || { echo "❌ .app not found at $APP" >&2; exit 1; }

# ─── 6. Package IPA ─────────────────────────────────────────
echo "▶ Packaging IPA…"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"

# Strip signing artifacts (eSign will inject its own)
rm -f "$BUILD_DIR/Payload/NixxTime.app/embedded.mobileprovision" 2>/dev/null || true
rm -rf "$BUILD_DIR/Payload/NixxTime.app/_CodeSignature" 2>/dev/null || true

cd "$BUILD_DIR"
zip -qry "$IPA" Payload
rm -rf Payload

# ─── 7. Done ────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ IPA: $IPA"
echo "  📦 Size: $(du -h "$IPA" | cut -f1)"
echo "═══════════════════════════════════════════════════════════"
