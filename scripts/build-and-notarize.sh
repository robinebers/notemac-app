#!/bin/bash
set -euo pipefail

# NoteMac Build & Notarize Script
# Usage: ./scripts/build-and-notarize.sh [--skip-notarize]
#
# Required environment variables:
#   SIGNING_IDENTITY   - Developer ID Application certificate name
#   KEYCHAIN_PROFILE   - notarytool keychain profile name
#
# Or create a .env file in the project root (see .env.example)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="NoteMac"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"

# Parse arguments first (before validation)
SKIP_NOTARIZE=false
for arg in "$@"; do
    case $arg in
        --skip-notarize) SKIP_NOTARIZE=true ;;
    esac
done

# Load .env if present
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Validate required env vars
: "${SIGNING_IDENTITY:?Error: SIGNING_IDENTITY not set. See .env.example}"
if [ "$SKIP_NOTARIZE" = false ]; then
    : "${KEYCHAIN_PROFILE:?Error: KEYCHAIN_PROFILE not set. See .env.example}"
fi

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building release executable..."
cd "$PROJECT_DIR"
swift build -c release

echo "==> Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# Copy resources (app icon)
if [ -d "Sources/$APP_NAME/Resources/Assets.xcassets" ]; then
    # Compile asset catalog
    xcrun actool "Sources/$APP_NAME/Resources/Assets.xcassets" \
        --compile "$APP_BUNDLE/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 15.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$BUILD_DIR/AssetCatalog.plist" 2>/dev/null || true
fi

# Copy any other resources from the bundle
if [ -d ".build/release/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R ".build/release/${APP_NAME}_${APP_NAME}.bundle/"* "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

echo "==> Signing app with hardened runtime..."
codesign --force \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "$PROJECT_DIR/NoteMac.entitlements" \
    --options runtime \
    --timestamp \
    "$APP_BUNDLE"

echo "==> Verifying signature..."
codesign --verify --verbose=2 "$APP_BUNDLE"
echo "==> Gatekeeper check..."
spctl -a -t exec -vv "$APP_BUNDLE" 2>&1 || echo "(Gatekeeper may require notarization)"

if [ "$SKIP_NOTARIZE" = true ]; then
    echo "==> Skipping notarization (--skip-notarize)"
    echo "==> Done! App bundle at: $APP_BUNDLE"
    exit 0
fi

echo "==> Creating ZIP for notarization..."
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"

echo "==> Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"

echo "==> Validating stapled ticket..."
xcrun stapler validate "$APP_BUNDLE"

echo "==> Final Gatekeeper check..."
spctl -a -t exec -vv "$APP_BUNDLE"

echo ""
echo "==> Done! Notarized app at: $APP_BUNDLE"
echo "==> ZIP for distribution: $ZIP_PATH"
