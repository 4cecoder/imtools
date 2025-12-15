#!/bin/bash
# Build Debian package for imtools
# Requirements: dpkg-dev, debhelper, zig
#
# Usage:
#   ./build-deb.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION="${VERSION:-1.0.0}"
BUILD_DIR="$PROJECT_ROOT/build-deb"

echo "Building imtools Debian package v${VERSION}"

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/imtools-${VERSION}"

# Copy source files
cp -r "$PROJECT_ROOT"/{src,build.zig,README.md,LICENSE,docs} "$BUILD_DIR/imtools-${VERSION}/"
cp -r "$SCRIPT_DIR/debian" "$BUILD_DIR/imtools-${VERSION}/"

# Build
cd "$BUILD_DIR/imtools-${VERSION}"
dpkg-buildpackage -us -uc -b

echo ""
echo "Debian package created in: $BUILD_DIR/"
ls -la "$BUILD_DIR"/*.deb

echo ""
echo "To install:"
echo "  sudo dpkg -i $BUILD_DIR/imtools_${VERSION}-1_amd64.deb"
