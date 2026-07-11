#!/bin/bash
set -euo pipefail

# setup.sh - Clone/update Ruffle into engine/ and build Ruffnova's FFI library.
# Usage: ./setup.sh [--target macos|ios|ios-sim|all]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE_DIR="${SCRIPT_DIR}/engine"
RUFFLE_REPO="https://github.com/ruffle-rs/ruffle.git"
RUFFLE_REV="b5c5517883504f713859fbab3ce299ac1fd371c0"  # pinned upstream commit
PATCH_DIR="${SCRIPT_DIR}/patches"
TARGET="all"

usage() {
    echo "Usage: $0 [--target macos|ios|ios-sim|all]"
    echo ""
    echo "Options:"
    echo "  --target <target>   Build target (default: all)"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

case "${TARGET}" in
    macos|ios|ios-sim|all) ;;
    *)
        echo "Unknown target: ${TARGET}" >&2
        usage >&2
        exit 1
        ;;
esac

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required tool: $1" >&2
        exit 1
    fi
}

require_tool git
require_tool cargo

if [[ "${TARGET}" == "ios" || "${TARGET}" == "all" ]]; then
    rustup target add aarch64-apple-ios
fi

if [[ "${TARGET}" == "ios-sim" || "${TARGET}" == "all" ]]; then
    rustup target add aarch64-apple-ios-sim
fi

# ─── Engine Setup ──────────────────────────────────────────────────────────────

if [[ -d "${ENGINE_DIR}/.git" ]]; then
    echo "Updating Ruffle in ${ENGINE_DIR}..."
    git -C "${ENGINE_DIR}" fetch --tags --prune origin
    echo "  Checking out pinned revision ${RUFFLE_REV:0:8}..."
    git -C "${ENGINE_DIR}" checkout --force "${RUFFLE_REV}"
elif [[ -e "${ENGINE_DIR}" ]]; then
    echo "${ENGINE_DIR} already exists but is not a git checkout." >&2
    echo "The existing engine/ directory will be moved to engine.bak/." >&2
    if [[ -d "${ENGINE_DIR}.bak" ]]; then
        echo "Removing previous backup engine.bak/..." >&2
        rm -rf "${ENGINE_DIR}.bak"
    fi
    mv "${ENGINE_DIR}" "${ENGINE_DIR}.bak"
    echo "Cloning Ruffle into ${ENGINE_DIR}..."
    git clone "${RUFFLE_REPO}" "${ENGINE_DIR}"
    echo "  Checking out pinned revision ${RUFFLE_REV:0:8}..."
    git -C "${ENGINE_DIR}" checkout "${RUFFLE_REV}"
else
    echo "Cloning Ruffle into ${ENGINE_DIR}..."
    git clone "${RUFFLE_REPO}" "${ENGINE_DIR}"
    echo "  Checking out pinned revision ${RUFFLE_REV:0:8}..."
    git -C "${ENGINE_DIR}" checkout "${RUFFLE_REV}"
fi

# ─── Apply Ruffnova FFI Patches ────────────────────────────────────────────────

if [[ -x "${PATCH_DIR}/apply.sh" ]]; then
    echo "Applying Ruffnova FFI patches..."
    "${PATCH_DIR}/apply.sh" "${ENGINE_DIR}"
else
    echo "Required FFI patch installer is missing: ${PATCH_DIR}/apply.sh" >&2
    exit 1
fi

# ─── Build ─────────────────────────────────────────────────────────────────────

echo "Building Ruffle FFI for ${TARGET}..."
"${SCRIPT_DIR}/build_engine.sh" --target "${TARGET}"

echo "Setup complete."
