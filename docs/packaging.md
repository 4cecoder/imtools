# Packaging Guide

Complete guide to packaging imtools for all major platforms and package managers.

## Table of Contents

- [Overview](#overview)
- [Package Files Location](#package-files-location)
- [Linux Package Managers](#linux-package-managers)
  - [Gentoo (Portage)](#gentoo-portage)
  - [Arch Linux (AUR)](#arch-linux-aur)
  - [Debian/Ubuntu (apt)](#debianubuntu-apt)
  - [Fedora/RHEL (dnf/yum)](#fedorarhel-dnfyum)
  - [Alpine (apk)](#alpine-apk)
  - [NixOS](#nixos)
- [Universal Linux Packages](#universal-linux-packages)
  - [Flatpak](#flatpak)
  - [Snap](#snap)
  - [AppImage](#appimage)
- [macOS](#macos)
  - [Homebrew](#homebrew)
- [Windows](#windows)
  - [Scoop](#scoop)
  - [Chocolatey](#chocolatey)
- [Static Binary Releases](#static-binary-releases)
- [GitHub Actions CI/CD](#github-actions-cicd)
- [Packaging Checklist](#packaging-checklist)

---

## Overview

imtools is designed for easy packaging:

| Property | Value |
|----------|-------|
| Source files | `src/main.zig`, `build.zig` |
| Build system | Zig (single command) |
| Runtime deps | None (core), ffmpeg/curl/ollama (optional) |
| License | MIT |
| Architectures | x86_64, aarch64 |

All packaging files are in the `packaging/` directory.

---

## Package Files Location

```
packaging/
├── gentoo/
│   ├── imtools-1.0.0.ebuild
│   ├── imtools-9999.ebuild
│   └── README.md
├── aur/
│   └── PKGBUILD
├── debian/
│   ├── debian/
│   │   ├── control
│   │   ├── rules
│   │   ├── changelog
│   │   ├── copyright
│   │   └── compat
│   └── build-deb.sh
├── rpm/
│   └── imtools.spec
├── alpine/
│   └── APKBUILD
├── nix/
│   ├── flake.nix
│   └── default.nix
├── flatpak/
│   └── io.github._4cecoder.imtools.yml
├── snap/
│   └── snapcraft.yaml
├── appimage/
│   └── build-appimage.sh
├── homebrew/
│   └── imtools.rb
├── scoop/
│   └── imtools.json
└── chocolatey/
    ├── imtools.nuspec
    └── tools/
        ├── chocolateyinstall.ps1
        └── chocolateyuninstall.ps1
```

---

## Linux Package Managers

### Gentoo (Portage)

**Files:** `packaging/gentoo/`

#### Quick Install

```bash
# Create local overlay (one-time setup)
sudo mkdir -p /var/db/repos/local/{metadata,profiles,media-gfx/imtools}
echo "local" | sudo tee /var/db/repos/local/profiles/repo_name
echo "masters = gentoo" | sudo tee /var/db/repos/local/metadata/layout.conf

# Register overlay
sudo mkdir -p /etc/portage/repos.conf
cat <<EOF | sudo tee /etc/portage/repos.conf/local.conf
[local]
location = /var/db/repos/local
EOF

# Copy and install stable ebuild
sudo cp packaging/gentoo/imtools-1.0.0.ebuild /var/db/repos/local/media-gfx/imtools/
cd /var/db/repos/local/media-gfx/imtools
sudo ebuild imtools-1.0.0.ebuild manifest
sudo emerge --ask media-gfx/imtools
```

#### USE Flags

| Flag | Default | Description |
|------|---------|-------------|
| `ffmpeg` | Yes | convert-to-png, download |
| `curl` | Yes | download, sort |
| `ollama` | No | AI sort |

See `packaging/gentoo/README.md` for detailed instructions.

---

### Arch Linux (AUR)

**Files:** `packaging/aur/PKGBUILD`

#### Build Locally

```bash
cd packaging/aur
makepkg -si
```

#### Submit to AUR

```bash
# Generate .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# Clone AUR repo and push
git clone ssh://aur@aur.archlinux.org/imtools.git aur-repo
cp PKGBUILD .SRCINFO aur-repo/
cd aur-repo
git add -A && git commit -m "Initial upload" && git push
```

---

### Debian/Ubuntu (apt)

**Files:** `packaging/debian/`

#### Build .deb Package

```bash
cd packaging/debian
./build-deb.sh

# Install
sudo dpkg -i ../build-deb/imtools_1.0.0-1_amd64.deb
```

#### Add to PPA (Ubuntu)

1. Create a Launchpad account
2. Set up a PPA
3. Upload source package with `dput`

---

### Fedora/RHEL (dnf/yum)

**Files:** `packaging/rpm/imtools.spec`

#### Build RPM

```bash
# Install build tools
sudo dnf install rpm-build rpmdevtools

# Setup rpmbuild directories
rpmdev-setuptree

# Copy spec and build
cp packaging/rpm/imtools.spec ~/rpmbuild/SPECS/
spectool -g -R ~/rpmbuild/SPECS/imtools.spec
rpmbuild -ba ~/rpmbuild/SPECS/imtools.spec
```

#### Submit to Fedora/EPEL

See [Fedora Package Review Process](https://docs.fedoraproject.org/en-US/package-maintainers/Package_Review_Process/).

---

### Alpine (apk)

**Files:** `packaging/alpine/APKBUILD`

#### Build Package

```bash
cd packaging/alpine
abuild -r
```

#### Submit to Alpine

See [Alpine Contributing Guide](https://wiki.alpinelinux.org/wiki/Creating_an_Alpine_package).

---

### NixOS

**Files:** `packaging/nix/`

#### Using Flake

```bash
# Build
nix build github:4cecoder/imtools

# Run directly
nix run github:4cecoder/imtools -- help

# Development shell
nix develop github:4cecoder/imtools
```

#### Using default.nix

```bash
nix-build packaging/nix/default.nix
./result/bin/imtools help
```

#### Add to NixOS Configuration

```nix
# configuration.nix
{ pkgs, ... }:
let
  imtools = pkgs.callPackage (builtins.fetchTarball {
    url = "https://github.com/4cecoder/imtools/archive/v1.0.0.tar.gz";
  } + "/packaging/nix/default.nix") {};
in {
  environment.systemPackages = [ imtools ];
}
```

---

## Universal Linux Packages

### Flatpak

**Files:** `packaging/flatpak/io.github._4cecoder.imtools.yml`

#### Build and Install

```bash
# Install flatpak-builder
sudo apt install flatpak-builder  # Debian/Ubuntu
sudo dnf install flatpak-builder  # Fedora

# Build
cd packaging/flatpak
flatpak-builder --user --install --force-clean build-dir io.github._4cecoder.imtools.yml

# Run
flatpak run io.github._4cecoder.imtools help
```

#### Submit to Flathub

See [Flathub Submission Guide](https://github.com/flathub/flathub/wiki/App-Submission).

---

### Snap

**Files:** `packaging/snap/snapcraft.yaml`

#### Build and Install

```bash
cd packaging/snap
snapcraft

# Install locally
sudo snap install imtools_1.0.0_amd64.snap --dangerous

# Run
snap run imtools help
```

#### Submit to Snap Store

```bash
snapcraft login
snapcraft upload imtools_1.0.0_amd64.snap
snapcraft release imtools <revision> stable
```

---

### AppImage

**Files:** `packaging/appimage/build-appimage.sh`

#### Build

```bash
cd packaging/appimage
./build-appimage.sh

# For ARM64
./build-appimage.sh --arch aarch64

# Run
chmod +x ../build-appimage/imtools-1.0.0-x86_64.AppImage
./imtools-1.0.0-x86_64.AppImage help
```

The script automatically:
- Builds a static binary with musl
- Creates AppDir structure
- Downloads appimagetool if needed
- Generates the AppImage

---

## macOS

### Homebrew

**Files:** `packaging/homebrew/imtools.rb`

#### Install from Formula

```bash
brew install --build-from-source packaging/homebrew/imtools.rb
```

#### Create a Tap

```bash
# Create tap repository on GitHub: yourusername/homebrew-tap
# Add formula
mkdir -p Formula
cp packaging/homebrew/imtools.rb Formula/

# Users can then:
brew tap yourusername/tap
brew install imtools
```

#### Submit to homebrew-core

See [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook).

---

## Windows

### Scoop

**Files:** `packaging/scoop/imtools.json`

#### Install from Manifest

```powershell
scoop install https://raw.githubusercontent.com/4cecoder/imtools/main/packaging/scoop/imtools.json
```

#### Create a Bucket

```bash
# Create bucket repository on GitHub: yourusername/scoop-bucket
# Add manifest
cp packaging/scoop/imtools.json bucket/

# Users can then:
scoop bucket add yourusername https://github.com/yourusername/scoop-bucket
scoop install imtools
```

---

### Chocolatey

**Files:** `packaging/chocolatey/`

#### Build Package

```powershell
cd packaging\chocolatey
choco pack

# Install locally
choco install imtools -s .
```

#### Submit to Chocolatey Community

```powershell
choco push imtools.1.0.0.nupkg --source https://push.chocolatey.org/
```

See [Chocolatey Package Creation](https://docs.chocolatey.org/en-us/create/create-packages).

---

## Static Binary Releases

Zig makes cross-compilation easy. Build static binaries for releases:

```bash
# Linux x86_64 (static with musl)
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl

# Linux ARM64
zig build -Doptimize=ReleaseSafe -Dtarget=aarch64-linux-musl

# macOS x86_64
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-macos

# macOS ARM64 (Apple Silicon)
zig build -Doptimize=ReleaseSafe -Dtarget=aarch64-macos

# Windows x86_64
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-windows
```

### Release Archive Structure

```
imtools-1.0.0-linux-x86_64.tar.gz
├── imtools
├── README.md
├── LICENSE
└── docs/
    ├── installation.md
    ├── commands.md
    └── ...
```

---

## GitHub Actions CI/CD

Example workflow for automated releases:

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            target: x86_64-linux-musl
            artifact: imtools-linux-x86_64
          - os: ubuntu-latest
            target: aarch64-linux-musl
            artifact: imtools-linux-aarch64
          - os: macos-latest
            target: x86_64-macos
            artifact: imtools-macos-x86_64
          - os: macos-latest
            target: aarch64-macos
            artifact: imtools-macos-aarch64
          - os: windows-latest
            target: x86_64-windows
            artifact: imtools-windows-x86_64

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.13.0

      - name: Build
        run: zig build -Doptimize=ReleaseSafe -Dtarget=${{ matrix.target }}

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact }}
          path: zig-out/bin/imtools*

  release:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download artifacts
        uses: actions/download-artifact@v4

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            imtools-linux-x86_64/*
            imtools-linux-aarch64/*
            imtools-macos-x86_64/*
            imtools-macos-aarch64/*
            imtools-windows-x86_64/*
```

---

## Packaging Checklist

When creating a new package:

### Required Files

- [ ] Binary: `imtools` (or `imtools.exe`)
- [ ] License: `LICENSE`
- [ ] Docs: `README.md`, `docs/`

### Metadata

| Field | Value |
|-------|-------|
| Name | `imtools` |
| Version | `1.0.0` |
| Description | Fast image manipulation CLI tool written in Zig |
| License | MIT |
| Homepage | https://github.com/4cecoder/imtools |
| Categories | Graphics, Utility, CLI |

### Dependencies

| Type | Package | Required For |
|------|---------|--------------|
| Build | zig >= 0.13 | All |
| Runtime | ffmpeg | convert-to-png, download |
| Runtime | curl | download, sort |
| Runtime | ollama | sort |

### Testing

After packaging, verify:

```bash
imtools help                     # Basic functionality
imtools flatten --dry-run        # File operations
imtools find-duplicates          # Hashing works
```

---

## Need Help?

- [GitHub Issues](https://github.com/4cecoder/imtools/issues)
- [Architecture Guide](architecture.md) - Build internals
- [Installation Guide](installation.md) - End-user install docs
