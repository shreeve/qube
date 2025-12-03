#!/bin/bash
#
# build-app.sh - Build Qube.app bundle for distribution
#
# Usage:
#   ./Scripts/build-app.sh          # Build release app
#   ./Scripts/build-app.sh --dmg    # Build release app + create DMG
#

set -e

# Configuration
APP_NAME="Qube"
BUNDLE_ID="com.qube.app"
VERSION="1.0.0"
BUILD_NUMBER="1"
MIN_MACOS="14.0"

# Directories
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
OUTPUT_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔨 Building $APP_NAME v$VERSION${NC}"
echo ""

# Step 1: Build release binary
echo -e "${BLUE}[1/4] Compiling Swift code...${NC}"
cd "$PROJECT_DIR"
swift build -c release

if [ ! -f "$BUILD_DIR/$APP_NAME" ]; then
    echo -e "${RED}❌ Build failed: Binary not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Binary compiled successfully${NC}"

# Step 2: Create app bundle structure
echo -e "${BLUE}[2/4] Creating app bundle...${NC}"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

echo -e "${GREEN}✓ App structure created${NC}"

# Step 3: Create Info.plist
echo -e "${BLUE}[3/4] Generating Info.plist...${NC}"
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo -e "${GREEN}✓ Info.plist created${NC}"

# Step 4: Copy icon if it exists
echo -e "${BLUE}[4/4] Adding resources...${NC}"
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    echo -e "${GREEN}✓ App icon added${NC}"
else
    echo -e "${BLUE}  ⚠ No icon found at Resources/AppIcon.icns (using default)${NC}"
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo ""
echo -e "${GREEN}✅ $APP_NAME.app created successfully!${NC}"
echo -e "   Location: $APP_BUNDLE"

# Get file size
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo -e "   Size: $APP_SIZE"

# Optional: Create DMG
if [ "$1" == "--dmg" ]; then
    echo ""
    echo -e "${BLUE}📦 Creating DMG...${NC}"

    DMG_NAME="$APP_NAME-$VERSION.dmg"
    DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

    # Remove old DMG
    rm -f "$DMG_PATH"

    # Create temporary directory for DMG contents
    DMG_TEMP="$OUTPUT_DIR/dmg-temp"
    rm -rf "$DMG_TEMP"
    mkdir -p "$DMG_TEMP"

    # Copy app to temp directory
    cp -R "$APP_BUNDLE" "$DMG_TEMP/"

    # Create symbolic link to Applications
    ln -s /Applications "$DMG_TEMP/Applications"

    # Create DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_TEMP" \
        -ov -format UDZO \
        "$DMG_PATH"

    # Cleanup
    rm -rf "$DMG_TEMP"

    DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
    echo -e "${GREEN}✅ DMG created: $DMG_PATH ($DMG_SIZE)${NC}"
fi

echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "   • Test: open \"$APP_BUNDLE\""
echo "   • Install: cp -R \"$APP_BUNDLE\" /Applications/"
if [ "$1" != "--dmg" ]; then
    echo "   • Create DMG: $0 --dmg"
fi
echo ""
echo -e "${BLUE}📝 Note: Recipients will need QEMU installed:${NC}"
echo "   brew install qemu"
