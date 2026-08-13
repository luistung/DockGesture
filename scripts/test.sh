#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TEST_BUILD_DIR="$LOCAL_BUILD_DIR/tests"
/bin/mkdir -p "$TEST_BUILD_DIR"

"$SWIFTC" "${SWIFT_COMMON_ARGS[@]}" \
    -warnings-as-errors \
    -enable-testing \
    -parse-as-library \
    -emit-module \
    -emit-library \
    -static \
    -module-name DockGestureCore \
    "$PROJECT_ROOT"/Sources/DockGestureCore/*.swift \
    -emit-module-path "$TEST_BUILD_DIR/DockGestureCore.swiftmodule" \
    -o "$TEST_BUILD_DIR/libDockGestureCore.a"

"$SWIFTC" "${SWIFT_COMMON_ARGS[@]}" \
    -warnings-as-errors \
    -I "$TEST_BUILD_DIR" \
    -L "$TEST_BUILD_DIR" \
    -lDockGestureCore \
    "$PROJECT_ROOT/Tests/ManualTestRunner/main.swift" \
    -o "$TEST_BUILD_DIR/DockGestureCoreTests"

"$TEST_BUILD_DIR/DockGestureCoreTests"
