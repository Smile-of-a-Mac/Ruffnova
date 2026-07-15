#!/bin/bash
set -euo pipefail

# build_engine.sh — Build libruffle_ffi.a for macOS, iOS devices, and iOS Simulator.
# Usage: ./build_engine.sh [--target macos|ios|ios-sim|all]
#
# Prerequisites:
#   rustup target add aarch64-apple-ios
#   rustup target add aarch64-apple-ios-sim

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE_DIR="${SCRIPT_DIR}/engine"
OUTPUT_DIR="${SCRIPT_DIR}/CRuffleFFI"
GENERATED_HEADER="${ENGINE_DIR}/ffi/include/ruffle_ffi.h"
PUBLIC_HEADER="${OUTPUT_DIR}/ruffle_ffi.h"

TARGET="${1:---target}"
TARGET_VALUE="${2:-all}"

if [[ "${TARGET}" != "--target" ]]; then
    echo "Usage: $0 [--target macos|ios|ios-sim|all]"
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

sync_header() {
    if [[ ! -f "${GENERATED_HEADER}" ]]; then
        echo "Error: cbindgen did not generate ${GENERATED_HEADER}" >&2
        exit 1
    fi
    cp "${GENERATED_HEADER}" "${PUBLIC_HEADER}"
    echo "  -> ${PUBLIC_HEADER}"
}

case "${TARGET_VALUE}" in
    macos)
        build_target "aarch64-apple-darwin" "macos"
        ;;
    ios)
        build_target "aarch64-apple-ios" "ios"
        ;;
    ios-sim)
        build_target "aarch64-apple-ios-sim" "ios-sim"
        ;;
    all)
        build_target "aarch64-apple-darwin" "macos"
        build_target "aarch64-apple-ios" "ios"
        build_target "aarch64-apple-ios-sim" "ios-sim"
        ;;
    *)
        echo "Unknown target: ${TARGET_VALUE}"
        echo "Valid targets: macos, ios, ios-sim, all"
        exit 1
        ;;
esac

sync_header

echo "Done."
