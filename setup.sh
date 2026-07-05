#!/bin/bash
set -euo pipefail

# setup.sh - Clone/update Ruffle into engine/ and build Ruffnova's FFI library.
# Usage: ./setup.sh [--target macos|ios|ios-sim|all]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE_DIR="${SCRIPT_DIR}/engine"
RUFFLE_REPO="https://github.com/ruffle-rs/ruffle.git"
TARGET="all"

usage() {
    echo "Usage: $0 [--target macos|ios|ios-sim|all]"
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

if [[ -d "${ENGINE_DIR}/.git" ]]; then
    echo "Updating Ruffle in ${ENGINE_DIR}..."
    git -C "${ENGINE_DIR}" fetch --tags --prune
    git -C "${ENGINE_DIR}" pull --ff-only
elif [[ -e "${ENGINE_DIR}" ]]; then
    echo "${ENGINE_DIR} already exists but is not a git checkout." >&2
    echo "Move it aside or remove it before running setup." >&2
    exit 1
else
    echo "Cloning Ruffle into ${ENGINE_DIR}..."
    git clone "${RUFFLE_REPO}" "${ENGINE_DIR}"
fi

echo "Building Ruffle FFI for ${TARGET}..."
"${SCRIPT_DIR}/build_engine.sh" --target "${TARGET}"

echo "Setup complete."
