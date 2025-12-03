#!/bin/bash
#
# create-icns.sh - Generate AppIcon.icns from a source image
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ICONSET_DIR="$SCRIPT_DIR/AppIcon.iconset"
OUTPUT_DIR="$PROJECT_DIR/Resources"

# Use the largest existing icon as source
SOURCE_IMAGE="$SCRIPT_DIR/AppIcon.appiconset/icon_512x512@2x.png"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Source image not found: $SOURCE_IMAGE"
    exit 1
fi

echo "🎨 Creating iconset from $SOURCE_IMAGE"

# Clean and create iconset directory
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate all required sizes
# macOS iconset requires specific filenames and sizes
sips -z 16 16     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
sips -z 32 32     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
sips -z 64 64     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
sips -z 256 256   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
sips -z 512 512   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

echo "✓ Generated icon sizes"

# Create icns file
mkdir -p "$OUTPUT_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_DIR/AppIcon.icns"

echo "✅ Created: $OUTPUT_DIR/AppIcon.icns"

# Cleanup
rm -rf "$ICONSET_DIR"

# Show file info
ls -lh "$OUTPUT_DIR/AppIcon.icns"
