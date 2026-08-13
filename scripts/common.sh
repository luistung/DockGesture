#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_BUILD_DIR="$PROJECT_ROOT/.build-local"
MODULE_CACHE_DIR="$LOCAL_BUILD_DIR/ModuleCache"
SWIFTC="$(/usr/bin/xcrun --find swiftc)"
SDK_PATH="$(/usr/bin/xcrun --show-sdk-path)"
TARGET_ARCH="$(/usr/bin/uname -m)"

/bin/mkdir -p "$LOCAL_BUILD_DIR" "$MODULE_CACHE_DIR"

SWIFT_COMMON_ARGS=(
    -swift-version 6
    -target "${TARGET_ARCH}-apple-macosx13.0"
    -sdk "$SDK_PATH"
    -module-cache-path "$MODULE_CACHE_DIR"
)

# Some mixed-version Command Line Tools installations contain the same
# SwiftBridging module in two module maps. Hide only the duplicate through a
# compiler VFS overlay; no system file is changed.
DUPLICATE_MODULE_MAP="/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap"
if [[ -f "$DUPLICATE_MODULE_MAP" ]]; then
    EMPTY_MODULE_MAP="$LOCAL_BUILD_DIR/empty.modulemap"
    OVERLAY_FILE="$LOCAL_BUILD_DIR/toolchain-overlay.yaml"
    /usr/bin/touch "$EMPTY_MODULE_MAP"
    /usr/bin/sed "s|__EMPTY_MODULEMAP__|$EMPTY_MODULE_MAP|g" \
        "$PROJECT_ROOT/Resources/CommandLineToolsOverlay.template.yaml" > "$OVERLAY_FILE"
    SWIFT_COMMON_ARGS+=( -vfsoverlay "$OVERLAY_FILE" )
fi
