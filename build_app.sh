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
DERIVED_DATA="${BUILD_DIR}/DerivedData"
SCHEME="Ruffnova"

echo "Building Ruffnova (${CONFIG}) via xcodebuild..."

xcodebuild -project "${PROJECT_DIR}/Ruffnova.xcodeproj" \
           -scheme "${SCHEME}" \
           -configuration "${CONFIG}" \
           -sdk macosx \
           -derivedDataPath "${DERIVED_DATA}" \
           build 2>&1 | tail -1

# Locate the built .app
APP_SRC="${DERIVED_DATA}/Build/Products/${CONFIG}/Ruffnova.app"
if [[ ! -d "${APP_SRC}" || ! -x "${APP_SRC}/Contents/MacOS/Ruffnova" || ! -f "${APP_SRC}/Contents/Info.plist" ]]; then
    echo "Error: Built .app not found in DerivedData" >&2
    exit 1
fi

APP="${BUILD_DIR}/Ruffnova.app"
DMG="${BUILD_DIR}/Ruffnova.dmg"
STAGING="${BUILD_DIR}/dmg-staging"

echo "Assembling .app bundle..."
rm -rf "${APP}"
cp -R "${APP_SRC}" "${APP}"

echo "Creating DMG..."
rm -rf "${STAGING}" "${DMG}"
mkdir -p "${STAGING}"
cp -R "${APP}" "${STAGING}/"

hdiutil create -volname "Ruffnova" -srcfolder "${STAGING}" -ov -format UDZO "${DMG}" 2>&1 | tail -1
rm -rf "${STAGING}"

echo "Done: ${DMG}"
