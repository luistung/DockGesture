#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

RELEASE_DIR="$LOCAL_BUILD_DIR/release"
PACKAGE_DIR="$LOCAL_BUILD_DIR/package"
APP_DIR="$PACKAGE_DIR/DockGesture.app"
OUTPUT_APP_DIR="$PROJECT_ROOT/outputs/DockGesture-1.0.3.app"
ZIP_PATH="$PROJECT_ROOT/outputs/DockGesture-1.0.3.zip"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

/bin/rm -rf "$APP_DIR" "$OUTPUT_APP_DIR"
/bin/mkdir -p "$RELEASE_DIR" "$MACOS_DIR" "$RESOURCES_DIR" "$PROJECT_ROOT/outputs"

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
/usr/bin/ditto "$PROJECT_ROOT/Resources/DockGesture.icns" "$RESOURCES_DIR/DockGesture.icns"
/usr/bin/codesign --force --deep --sign - "$APP_DIR"
/usr/bin/ditto "$APP_DIR" "$OUTPUT_APP_DIR"
/bin/rm -f "$ZIP_PATH"
(
    cd "$PROJECT_ROOT/outputs"
    /usr/bin/zip -qryX "DockGesture-1.0.3.zip" "DockGesture-1.0.3.app"
)

echo "Built $OUTPUT_APP_DIR"
echo "Archived $ZIP_PATH"
