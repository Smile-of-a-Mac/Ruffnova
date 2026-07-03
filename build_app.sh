#!/bin/bash
set -euo pipefail

# build_app.sh — Build Ruffnova .app and package into .dmg.
# Usage: ./build_app.sh [--release]

CONFIG="Debug"
if [[ "${1:-}" == "--release" ]]; then
    CONFIG="Release"
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build"
DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
SCHEME="Ruffnova"

echo "Building Ruffnova (${CONFIG}) via xcodebuild..."

xcodebuild -project "${PROJECT_DIR}/Ruffnova.xcodeproj" \
           -scheme "${SCHEME}" \
           -configuration "${CONFIG}" \
           -sdk macosx \
           build 2>&1 | tail -1

# Locate the built .app
APP_SRC=$(find "${DERIVED_DATA}" -name "Ruffnova.app" -path "*/Products/${CONFIG}/*" -type d 2>/dev/null | head -1)
if [[ -z "${APP_SRC}" ]]; then
    echo "Error: Built .app not found in DerivedData" >&2
    exit 1
fi

APP="${BUILD_DIR}/Ruffnova.app"
DMG="${BUILD_DIR}/Ruffnova.dmg"
STAGING="${BUILD_DIR}/dmg-staging"

echo "Assembling .app bundle..."
rm -rf "${APP}"
cp -R "${APP_SRC}" "${APP}"

# Generate AppIcon.icns if missing and iconutil is available
ICON_SOURCE="${PROJECT_DIR}/Assets.xcassets/AppIcon.appiconset"
ICONSET="${BUILD_DIR}/AppIcon.iconset"
if [[ -d "${ICON_SOURCE}" ]] && command -v iconutil >/dev/null 2>&1; then
    rm -rf "${ICONSET}"
    mkdir -p "${ICONSET}"
    for size in 16 32 128 256 512; do
        if [[ -f "${ICON_SOURCE}/icon_${size}x${size}.png" ]]; then
            cp "${ICON_SOURCE}/icon_${size}x${size}.png" "${ICONSET}/icon_${size}x${size}.png"
        fi
        if [[ -f "${ICON_SOURCE}/icon_${size}x${size}@2x.png" ]]; then
            cp "${ICON_SOURCE}/icon_${size}x${size}@2x.png" "${ICONSET}/icon_${size}x${size}@2x.png"
        fi
    done
    iconutil -c icns "${ICONSET}" -o "${APP}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
fi

echo "Creating DMG..."
rm -rf "${STAGING}" "${DMG}"
mkdir -p "${STAGING}"
cp -R "${APP}" "${STAGING}/"

hdiutil create -volname "Ruffnova" -srcfolder "${STAGING}" -ov -format UDZO "${DMG}" 2>&1 | tail -1
rm -rf "${STAGING}"

echo "Done: ${DMG}"
