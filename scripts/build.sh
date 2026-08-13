#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

RELEASE_DIR="$LOCAL_BUILD_DIR/release"
APP_DIR="$PROJECT_ROOT/outputs/DockGesture.app"
ZIP_PATH="$PROJECT_ROOT/outputs/DockGesture.zip"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

/bin/mkdir -p "$RELEASE_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

"$SWIFTC" "${SWIFT_COMMON_ARGS[@]}" \
    -warnings-as-errors \
    -O \
    -whole-module-optimization \
    -parse-as-library \
    -emit-module \
    -emit-library \
    -static \
    -module-name DockGestureCore \
    "$PROJECT_ROOT"/Sources/DockGestureCore/*.swift \
    -emit-module-path "$RELEASE_DIR/DockGestureCore.swiftmodule" \
    -o "$RELEASE_DIR/libDockGestureCore.a"

"$SWIFTC" "${SWIFT_COMMON_ARGS[@]}" \
    -warnings-as-errors \
    -O \
    -whole-module-optimization \
    -I "$RELEASE_DIR" \
    -L "$RELEASE_DIR" \
    -lDockGestureCore \
    -framework AppKit \
    -framework ApplicationServices \
    -framework ServiceManagement \
    "$PROJECT_ROOT"/Sources/DockGesture/*.swift \
    -o "$MACOS_DIR/DockGesture"

/usr/bin/ditto "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/bin/codesign --force --deep --sign - "$APP_DIR"
/bin/rm -f "$ZIP_PATH"
(
    cd "$PROJECT_ROOT/outputs"
    /usr/bin/zip -qryX "DockGesture.zip" "DockGesture.app"
)

echo "Built $APP_DIR"
echo "Archived $ZIP_PATH"
