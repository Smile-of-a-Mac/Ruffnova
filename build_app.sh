#!/bin/bash
set -euo pipefail

# build_app.sh — Build Ruffnova as a proper macOS .app bundle.
# Usage: ./build_app.sh [--release]

CONFIG="debug"
if [[ "${1:-}" == "--release" ]]; then
    CONFIG="release"
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build"
BINARY="${BUILD_DIR}/${CONFIG}/Ruffnova"
APP="${BUILD_DIR}/Ruffnova.app"

echo "Building Ruffnova (${CONFIG})..."

swift build -c "${CONFIG}" --package-path "${PROJECT_DIR}"

if [[ ! -f "${BINARY}" ]]; then
    echo "Error: Binary not found at ${BINARY}" >&2
    exit 1
fi

echo "Assembling .app bundle..."

# Clean previous bundle
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS"
mkdir -p "${APP}/Contents/Resources"

# Copy binary
cp "${BINARY}" "${APP}/Contents/MacOS/Ruffnova"

# Copy Info.plist
cp "${PROJECT_DIR}/Info.plist" "${APP}/Contents/Info.plist"

# Copy asset catalog
if [[ -d "${PROJECT_DIR}/Assets.xcassets" ]]; then
    cp -R "${PROJECT_DIR}/Assets.xcassets" "${APP}/Contents/Resources/Assets.xcassets"
fi

# Generate macOS .icns app icon for Finder/Dock.
ICON_SOURCE="${PROJECT_DIR}/Assets.xcassets/AppIcon.appiconset"
ICONSET="${BUILD_DIR}/AppIcon.iconset"
if [[ -d "${ICON_SOURCE}" ]] && command -v iconutil >/dev/null 2>&1; then
    rm -rf "${ICONSET}"
    mkdir -p "${ICONSET}"
    cp "${ICON_SOURCE}/icon_16x16.png" "${ICONSET}/icon_16x16.png"
    cp "${ICON_SOURCE}/icon_16x16@2x.png" "${ICONSET}/icon_16x16@2x.png"
    cp "${ICON_SOURCE}/icon_32x32.png" "${ICONSET}/icon_32x32.png"
    cp "${ICON_SOURCE}/icon_32x32@2x.png" "${ICONSET}/icon_32x32@2x.png"
    cp "${ICON_SOURCE}/icon_128x128.png" "${ICONSET}/icon_128x128.png"
    cp "${ICON_SOURCE}/icon_128x128@2x.png" "${ICONSET}/icon_128x128@2x.png"
    cp "${ICON_SOURCE}/icon_256x256.png" "${ICONSET}/icon_256x256.png"
    cp "${ICON_SOURCE}/icon_256x256@2x.png" "${ICONSET}/icon_256x256@2x.png"
    cp "${ICON_SOURCE}/icon_512x512.png" "${ICONSET}/icon_512x512.png"
    cp "${ICON_SOURCE}/icon_512x512@2x.png" "${ICONSET}/icon_512x512@2x.png"
    iconutil -c icns "${ICONSET}" -o "${APP}/Contents/Resources/AppIcon.icns"
fi

# Copy any additional resources
if [[ -d "${PROJECT_DIR}/Resources" ]]; then
    cp -R "${PROJECT_DIR}/Resources" "${APP}/Contents/Resources/"
fi

# Generate PkgInfo
echo -n "APPL????" > "${APP}/Contents/PkgInfo"

echo "Done: ${APP}"
echo "Run: open \"${APP}\""
