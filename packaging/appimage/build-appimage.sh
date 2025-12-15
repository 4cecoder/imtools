#!/bin/bash
# Build AppImage for imtools
# Requirements: zig, appimagetool (or linuxdeploy)
#
# Usage:
#   ./build-appimage.sh
#   ./build-appimage.sh --arch aarch64  # Cross-compile for ARM64

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build-appimage"
APPDIR="$BUILD_DIR/AppDir"
VERSION="${VERSION:-1.0.0}"
ARCH="${ARCH:-x86_64}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Building imtools AppImage v${VERSION} for ${ARCH}"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$APPDIR/usr/share/doc/imtools"

# Build imtools
cd "$PROJECT_ROOT"
case $ARCH in
    x86_64)
        zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl
        ;;
    aarch64)
        zig build -Doptimize=ReleaseSafe -Dtarget=aarch64-linux-musl
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Copy binary
cp zig-out/bin/imtools "$APPDIR/usr/bin/"
chmod +x "$APPDIR/usr/bin/imtools"

# Copy documentation
cp README.md LICENSE "$APPDIR/usr/share/doc/imtools/"
cp -r docs "$APPDIR/usr/share/doc/imtools/"

# Create .desktop file
cat > "$APPDIR/usr/share/applications/imtools.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=imtools
GenericName=Image Tools
Comment=Fast image manipulation CLI tool
Exec=imtools %F
Icon=imtools
Categories=Graphics;Utility;
Terminal=true
MimeType=image/png;image/jpeg;image/gif;image/bmp;image/webp;
Keywords=image;wallpaper;duplicate;convert;sort;
EOF

# Copy desktop file to AppDir root (required by AppImage)
cp "$APPDIR/usr/share/applications/imtools.desktop" "$APPDIR/"

# Create simple icon (placeholder - replace with actual icon)
cat > "$APPDIR/usr/share/icons/hicolor/256x256/apps/imtools.svg" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <rect width="256" height="256" rx="32" fill="#2d3748"/>
  <text x="128" y="160" font-family="monospace" font-size="120" font-weight="bold" fill="#48bb78" text-anchor="middle">im</text>
</svg>
EOF

# Create symlink for icon at root
ln -sf usr/share/icons/hicolor/256x256/apps/imtools.svg "$APPDIR/imtools.svg"

# Create AppRun script
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
exec "${HERE}/usr/bin/imtools" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Download appimagetool if not available
APPIMAGETOOL="$BUILD_DIR/appimagetool"
if ! command -v appimagetool &> /dev/null && [ ! -f "$APPIMAGETOOL" ]; then
    echo "Downloading appimagetool..."
    case $ARCH in
        x86_64)
            TOOL_ARCH="x86_64"
            ;;
        aarch64)
            TOOL_ARCH="aarch64"
            ;;
    esac
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${TOOL_ARCH}.AppImage" -O "$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

# Build AppImage
cd "$BUILD_DIR"
if command -v appimagetool &> /dev/null; then
    ARCH=$ARCH appimagetool AppDir "imtools-${VERSION}-${ARCH}.AppImage"
else
    ARCH=$ARCH "$APPIMAGETOOL" AppDir "imtools-${VERSION}-${ARCH}.AppImage"
fi

echo ""
echo "AppImage created: $BUILD_DIR/imtools-${VERSION}-${ARCH}.AppImage"
echo ""
echo "To test:"
echo "  chmod +x imtools-${VERSION}-${ARCH}.AppImage"
echo "  ./imtools-${VERSION}-${ARCH}.AppImage help"
