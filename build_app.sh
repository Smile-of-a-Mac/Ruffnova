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
cp "${PROJECT_DIR}/Ruffnova/Info.plist" "${APP}/Contents/Info.plist"

# Copy asset catalog
if [[ -d "${PROJECT_DIR}/Ruffnova/Assets.xcassets" ]]; then
    cp -R "${PROJECT_DIR}/Ruffnova/Assets.xcassets" "${APP}/Contents/Resources/Assets.xcassets"
fi

# Copy any additional resources
if [[ -d "${PROJECT_DIR}/Ruffnova/Resources" ]]; then
    cp -R "${PROJECT_DIR}/Ruffnova/Resources" "${APP}/Contents/Resources/"
fi

# Generate PkgInfo
echo -n "APPL????" > "${APP}/Contents/PkgInfo"

echo "Done: ${APP}"
echo "Run: open \"${APP}\""
