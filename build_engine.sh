#!/bin/bash
set -euo pipefail

# build_engine.sh — Build libruffle_ffi.a for macOS and iOS devices.
# Usage: ./build_engine.sh [--target macos|ios|all]
#
# Prerequisites:
#   rustup target add aarch64-apple-ios

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE_DIR="${SCRIPT_DIR}/engine"
OUTPUT_DIR="${SCRIPT_DIR}/CRuffleFFI"

TARGET="${1:---target}"
TARGET_VALUE="${2:-all}"

if [[ "${TARGET}" != "--target" ]]; then
    echo "Usage: $0 [--target macos|ios|all]"
    exit 1
fi

build_target() {
    local rust_target=$1
    local output_subdir=$2
    echo "Building for ${rust_target}..."
    cargo build --release \
        --target "${rust_target}" \
        --manifest-path "${ENGINE_DIR}/ffi/Cargo.toml"

    mkdir -p "${OUTPUT_DIR}/${output_subdir}"
    cp "${ENGINE_DIR}/target/${rust_target}/release/libruffle_ffi.a" \
       "${OUTPUT_DIR}/${output_subdir}/"
    echo "  -> ${OUTPUT_DIR}/${output_subdir}/libruffle_ffi.a"
}

case "${TARGET_VALUE}" in
    macos)
        build_target "aarch64-apple-darwin" "macos"
        ;;
    ios)
        build_target "aarch64-apple-ios" "ios"
        ;;
    all)
        build_target "aarch64-apple-darwin" "macos"
        build_target "aarch64-apple-ios" "ios"
        ;;
    *)
        echo "Unknown target: ${TARGET_VALUE}"
        echo "Valid targets: macos, ios, all"
        exit 1
        ;;
esac

echo "Done."
