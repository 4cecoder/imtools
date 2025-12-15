#!/bin/bash
# Version bump script for imtools
# Usage:
#   ./scripts/bump-version.sh patch   # 1.0.0 -> 1.0.1
#   ./scripts/bump-version.sh minor   # 1.0.0 -> 1.1.0
#   ./scripts/bump-version.sh major   # 1.0.0 -> 2.0.0
#   ./scripts/bump-version.sh 2.0.0   # Set specific version

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get current version from packaging files
CURRENT_VERSION=$(grep -oP 'version.*?"\K[0-9]+\.[0-9]+\.[0-9]+' "$PROJECT_ROOT/packaging/scoop/imtools.json" | head -1)

if [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Could not determine current version"
    exit 1
fi

echo "Current version: $CURRENT_VERSION"

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Determine new version
case "$1" in
    major)
        NEW_VERSION="$((MAJOR + 1)).0.0"
        ;;
    minor)
        NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
        ;;
    patch)
        NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
        ;;
    [0-9]*.[0-9]*.[0-9]*)
        NEW_VERSION="$1"
        ;;
    *)
        echo "Usage: $0 {major|minor|patch|X.Y.Z}"
        echo ""
        echo "Examples:"
        echo "  $0 patch    # $CURRENT_VERSION -> $MAJOR.$MINOR.$((PATCH + 1))"
        echo "  $0 minor    # $CURRENT_VERSION -> $MAJOR.$((MINOR + 1)).0"
        echo "  $0 major    # $CURRENT_VERSION -> $((MAJOR + 1)).0.0"
        echo "  $0 2.0.0    # Set specific version"
        exit 1
        ;;
esac

echo "New version: $NEW_VERSION"
echo ""

# Confirm
read -p "Proceed with version bump? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Updating version in files..."

# Update packaging/scoop/imtools.json
sed -i "s/\"version\": \"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" "$PROJECT_ROOT/packaging/scoop/imtools.json"
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/scoop/imtools.json"
echo "  Updated: packaging/scoop/imtools.json"

# Update packaging/chocolatey/imtools.nuspec
sed -i "s/<version>$CURRENT_VERSION</<version>$NEW_VERSION</g" "$PROJECT_ROOT/packaging/chocolatey/imtools.nuspec"
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/chocolatey/imtools.nuspec"
echo "  Updated: packaging/chocolatey/imtools.nuspec"

# Update packaging/chocolatey/tools/chocolateyinstall.ps1
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/chocolatey/tools/chocolateyinstall.ps1"
echo "  Updated: packaging/chocolatey/tools/chocolateyinstall.ps1"

# Update packaging/homebrew/imtools.rb
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/homebrew/imtools.rb"
echo "  Updated: packaging/homebrew/imtools.rb"

# Update packaging/snap/snapcraft.yaml
sed -i "s/version: '$CURRENT_VERSION'/version: '$NEW_VERSION'/" "$PROJECT_ROOT/packaging/snap/snapcraft.yaml"
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/snap/snapcraft.yaml"
echo "  Updated: packaging/snap/snapcraft.yaml"

# Update packaging/flatpak manifest
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/flatpak/io.github._4cecoder.imtools.yml"
echo "  Updated: packaging/flatpak/io.github._4cecoder.imtools.yml"

# Update packaging/aur/PKGBUILD
sed -i "s/pkgver=$CURRENT_VERSION/pkgver=$NEW_VERSION/" "$PROJECT_ROOT/packaging/aur/PKGBUILD"
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/aur/PKGBUILD"
echo "  Updated: packaging/aur/PKGBUILD"

# Update packaging/alpine/APKBUILD
sed -i "s/pkgver=$CURRENT_VERSION/pkgver=$NEW_VERSION/" "$PROJECT_ROOT/packaging/alpine/APKBUILD"
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/alpine/APKBUILD"
echo "  Updated: packaging/alpine/APKBUILD"

# Update packaging/rpm/imtools.spec
sed -i "s/Version:        $CURRENT_VERSION/Version:        $NEW_VERSION/" "$PROJECT_ROOT/packaging/rpm/imtools.spec"
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/rpm/imtools.spec"
echo "  Updated: packaging/rpm/imtools.spec"

# Update packaging/nix/default.nix
sed -i "s/version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" "$PROJECT_ROOT/packaging/nix/default.nix"
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$PROJECT_ROOT/packaging/nix/default.nix"
echo "  Updated: packaging/nix/default.nix"

# Update packaging/nix/flake.nix
sed -i "s/version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" "$PROJECT_ROOT/packaging/nix/flake.nix"
echo "  Updated: packaging/nix/flake.nix"

# Update packaging/debian/debian/changelog (add new entry at top)
DATE=$(date -R)
CHANGELOG_ENTRY="imtools ($NEW_VERSION-1) unstable; urgency=medium

  * Release $NEW_VERSION

 -- 4cecoder <4cecoder@users.noreply.github.com>  $DATE
"
echo "$CHANGELOG_ENTRY
$(cat "$PROJECT_ROOT/packaging/debian/debian/changelog")" > "$PROJECT_ROOT/packaging/debian/debian/changelog"
echo "  Updated: packaging/debian/debian/changelog"

# Update Gentoo ebuilds (rename and update)
if [ -f "$PROJECT_ROOT/packaging/gentoo/imtools-$CURRENT_VERSION.ebuild" ]; then
    mv "$PROJECT_ROOT/packaging/gentoo/imtools-$CURRENT_VERSION.ebuild" \
       "$PROJECT_ROOT/packaging/gentoo/imtools-$NEW_VERSION.ebuild"
    echo "  Renamed: packaging/gentoo/imtools-$NEW_VERSION.ebuild"
fi

# Update CHANGELOG.md if it exists
if [ -f "$PROJECT_ROOT/CHANGELOG.md" ]; then
    DATE_SHORT=$(date +%Y-%m-%d)
    sed -i "s/## \[Unreleased\]/## [Unreleased]\n\n## [$NEW_VERSION] - $DATE_SHORT/" "$PROJECT_ROOT/CHANGELOG.md"
    echo "  Updated: CHANGELOG.md"
fi

echo ""
echo "Version bumped to $NEW_VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Update CHANGELOG.md with release notes"
echo "  3. Commit: git add -A && git commit -m \"Bump version to $NEW_VERSION\""
echo "  4. Tag: git tag v$NEW_VERSION"
echo "  5. Push: git push && git push --tags"
echo ""
echo "The GitHub Actions release workflow will automatically:"
echo "  - Build binaries for all platforms"
echo "  - Create GitHub Release with assets"
echo "  - Generate checksums"
