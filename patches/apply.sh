#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE_DIR="$1"
RUFFLE_REV="b5c5517883504f713859fbab3ce299ac1fd371c0"

if [[ -z "$ENGINE_DIR" ]]; then
    echo "Usage: $0 <engine-directory>" >&2
    exit 1
fi

if [[ ! -d "${ENGINE_DIR}/.git" ]]; then
    echo "${ENGINE_DIR} is not a Ruffle git checkout." >&2
    exit 1
fi

if [[ "$(git -C "${ENGINE_DIR}" rev-parse HEAD)" != "${RUFFLE_REV}" ]]; then
    echo "Ruffnova patches require Ruffle revision ${RUFFLE_REV}." >&2
    exit 1
fi

echo "Applying Ruffnova FFI patches..."

# 1. Overlay our custom ffi crate (does not exist in upstream Ruffle)
if [[ ! -d "${SCRIPT_DIR}/engine/ffi" ]]; then
    echo "Required FFI patch is missing." >&2
    exit 1
fi
echo "  -> Copying custom ffi crate"
rsync -a --delete "${SCRIPT_DIR}/engine/ffi/" "${ENGINE_DIR}/ffi/"

# 2. Overlay enhanced storage backend with atomic writes, listing, quota
if [[ ! -f "${SCRIPT_DIR}/engine/frontend-utils/src/backends/storage.rs" ]]; then
    echo "Required storage backend patch is missing." >&2
    exit 1
fi
echo "  -> Applying enhanced storage backend"
cp "${SCRIPT_DIR}/engine/frontend-utils/src/backends/storage.rs" \
   "${ENGINE_DIR}/frontend-utils/src/backends/storage.rs"

echo "Patches applied successfully."
