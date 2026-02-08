#!/bin/bash
# Build CCNotifier universal binary for macOS
# Requires: Xcode Command Line Tools (xcode-select --install)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SCRIPT_DIR}/src/main.swift"
APP_DIR="${SCRIPT_DIR}/CCNotifier.app"
BIN_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"
BUILD_DIR="${SCRIPT_DIR}/.build"
OUTPUT="${BIN_DIR}/CCNotifier"
SIGN_IDENTITY="${CC_NOTIFIER_SIGN_IDENTITY:--}"

echo "=== Building CCNotifier ==="

# Ensure directories exist
mkdir -p "$BIN_DIR" "$RESOURCES_DIR" "$BUILD_DIR"

# Compile for arm64
echo "Compiling for arm64..."
swiftc -O -target arm64-apple-macosx11.0 \
  -o "${BUILD_DIR}/CCNotifier-arm64" \
  "$SRC"

# Compile for x86_64
echo "Compiling for x86_64..."
swiftc -O -target x86_64-apple-macosx11.0 \
  -o "${BUILD_DIR}/CCNotifier-x86_64" \
  "$SRC"

# Create universal binary
echo "Creating universal binary..."
lipo -create \
  "${BUILD_DIR}/CCNotifier-arm64" \
  "${BUILD_DIR}/CCNotifier-x86_64" \
  -output "$OUTPUT"

chmod +x "$OUTPUT"

# Sound files are bundled Pixabay-licensed AIFF files tracked in git
# (no system sound copy needed)

# Code sign (set CC_NOTIFIER_SIGN_IDENTITY to use Developer ID)
echo "Code signing..."
codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR"
if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "Warning: ad-hoc signature in use. Set CC_NOTIFIER_SIGN_IDENTITY for stronger provenance."
fi

# Cleanup build temp
rm -rf "$BUILD_DIR"

# Verify
echo ""
echo "=== Build Complete ==="
lipo -info "$OUTPUT"
if command -v shasum >/dev/null 2>&1; then
  echo "SHA256: $(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
fi
echo "App bundle: ${APP_DIR}"
