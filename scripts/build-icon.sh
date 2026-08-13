#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_ICON_DIR="$PROJECT_ROOT/Resources/AppIcon"
ICONSET_DIR="$APP_ICON_DIR/DockGesture.iconset"
MAIN_SVG="$APP_ICON_DIR/DockGesture.svg"
SMALL_SVG="$APP_ICON_DIR/DockGesture-small.svg"
ICNS_PATH="$PROJECT_ROOT/Resources/DockGesture.icns"
PREVIEW_PATH="$APP_ICON_DIR/DockGesture-1024.png"
RSVG_CONVERT="${RSVG_CONVERT:-/opt/homebrew/bin/rsvg-convert}"

if [[ ! -x "$RSVG_CONVERT" ]]; then
    echo "rsvg-convert not found at $RSVG_CONVERT" >&2
    exit 1
fi

/bin/rm -rf "$ICONSET_DIR"
/bin/mkdir -p "$ICONSET_DIR"

render() {
    local source_svg="$1"
    local size="$2"
    local output_path="$3"

    "$RSVG_CONVERT" \
        --width "$size" \
        --height "$size" \
        --keep-aspect-ratio \
        --output "$output_path" \
        "$source_svg"
}

render "$SMALL_SVG" 16 "$ICONSET_DIR/icon_16x16.png"
render "$SMALL_SVG" 32 "$ICONSET_DIR/icon_16x16@2x.png"
render "$SMALL_SVG" 32 "$ICONSET_DIR/icon_32x32.png"
render "$SMALL_SVG" 64 "$ICONSET_DIR/icon_32x32@2x.png"
render "$MAIN_SVG" 128 "$ICONSET_DIR/icon_128x128.png"
render "$MAIN_SVG" 256 "$ICONSET_DIR/icon_128x128@2x.png"
render "$MAIN_SVG" 256 "$ICONSET_DIR/icon_256x256.png"
render "$MAIN_SVG" 512 "$ICONSET_DIR/icon_256x256@2x.png"
render "$MAIN_SVG" 512 "$ICONSET_DIR/icon_512x512.png"
render "$MAIN_SVG" 1024 "$ICONSET_DIR/icon_512x512@2x.png"
render "$MAIN_SVG" 1024 "$PREVIEW_PATH"

/usr/bin/iconutil --convert icns --output "$ICNS_PATH" "$ICONSET_DIR"

echo "Built $ICNS_PATH"
echo "Preview $PREVIEW_PATH"
