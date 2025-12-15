# imtools - Image Manipulation Tools

A fast, standalone image manipulation CLI tool written in Zig that replaces ImageMagick for common wallpaper management tasks.

## Features

**No external dependencies** - All image format parsing is built-in:
- PNG, JPEG, GIF, BMP, WebP dimension detection
- SHA256-based duplicate detection
- File system operations

## Installation

### Gentoo (Portage)

Set up a local overlay and install via emerge:

```bash
# Create local overlay structure
doas mkdir -p /var/db/repos/local/{metadata,profiles,media-gfx/imtools}
echo "local" | doas tee /var/db/repos/local/profiles/repo_name
echo "masters = gentoo" | doas tee /var/db/repos/local/metadata/layout.conf

# Register the overlay
doas mkdir -p /etc/portage/repos.conf
cat <<EOF | doas tee /etc/portage/repos.conf/local.conf
[local]
location = /var/db/repos/local
EOF

# Copy the ebuild
doas cp imtools-1.0.0.ebuild /var/db/repos/local/media-gfx/imtools/

# Generate manifest and install
cd /var/db/repos/local/media-gfx/imtools
doas ebuild imtools-1.0.0.ebuild manifest
doas emerge --ask media-gfx/imtools
```

> **Note:** Replace `doas` with `sudo` if that's what you use.

### Manual Installation

Requires Zig 0.13 or later:

```bash
# Build
zig build -Doptimize=ReleaseSafe

# Install to ~/.local/bin (user)
cp zig-out/bin/imtools ~/.local/bin/

# Or install system-wide
doas cp zig-out/bin/imtools /usr/local/bin/
```

## Commands

### flatten
Move all images from subdirectories to current directory.

```bash
imtools flatten [--dry-run]
```

### find-duplicates
Find duplicate images by comparing SHA256 hashes.

```bash
imtools find-duplicates [--delete]
```

With `--delete`, prompts interactively to delete duplicates (keeps first occurrence).

### delete-portrait
Delete all portrait orientation images (height > width).

```bash
imtools delete-portrait [--dry-run]
```

### remove-empty-dirs
Recursively remove empty directories.

```bash
imtools remove-empty-dirs [--dry-run]
```

### convert-to-png
Convert all images to PNG format. Requires `ffmpeg`.

```bash
imtools convert-to-png [--dry-run]
imtools convert-to-png --delete  # delete originals after conversion
```

## Supported Image Formats

- PNG
- JPEG/JPG
- GIF
- BMP
- WebP
- TIFF (basic support)

## Performance

Built in Zig for:
- Fast startup (no runtime overhead)
- Low memory usage
- Native performance

## License

MIT
