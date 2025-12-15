# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2024-12-15

### Added

- **Core Commands**
  - `flatten` - Move images from nested subdirectories to current directory
  - `find-duplicates` - Find duplicate images by SHA256 hash with optional deletion
  - `delete-portrait` - Delete portrait-oriented images (height > width)
  - `remove-empty-dirs` - Recursively remove empty directories
  - `convert-to-png` - Batch convert images to PNG format (requires ffmpeg)

- **Download Command**
  - Download wallpapers from wallhaven.cc
  - Automatic JPG to PNG conversion
  - Configurable search query and limit

- **AI-Powered Sorting**
  - Local AI image categorization via Ollama vision models
  - 50+ auto-detected categories (nature, anime, space, etc.)
  - Custom category support
  - Parallel processing with configurable workers

- **Image Format Support**
  - Native header parsing for PNG, JPEG, GIF, BMP, WebP
  - Basic TIFF support
  - No external libraries required for dimension detection

- **Packaging**
  - Gentoo ebuilds (stable + live)
  - Arch Linux PKGBUILD (AUR-ready)
  - Debian/Ubuntu .deb packaging
  - Fedora/RHEL RPM spec
  - Alpine APKBUILD
  - NixOS flake + default.nix
  - Flatpak manifest
  - Snap package
  - AppImage build script
  - Homebrew formula (macOS)
  - Scoop manifest (Windows)
  - Chocolatey package (Windows)

- **Documentation**
  - Comprehensive README with quick start guide
  - Installation guide for all platforms
  - Complete command reference
  - AI sorting setup guide
  - Architecture & contributing guide
  - Packaging guide for maintainers

### Technical

- Single-file Zig implementation (~1900 lines)
- Zero runtime dependencies for core features
- Cross-platform (Linux, macOS, Windows)
- Static binary builds via musl

[Unreleased]: https://github.com/4cecoder/imtools/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/4cecoder/imtools/releases/tag/v1.0.0
