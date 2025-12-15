# Packaging Guide

How to package imtools for various Linux distributions and systems.

## Table of Contents

- [Overview](#overview)
- [Gentoo (Ebuild)](#gentoo-ebuild)
- [Arch Linux (PKGBUILD)](#arch-linux-pkgbuild)
- [Debian/Ubuntu (.deb)](#debianubuntu-deb)
- [Fedora/RHEL (RPM)](#fedorarhel-rpm)
- [Nix (Flake)](#nix-flake)
- [Homebrew (macOS/Linux)](#homebrew-macoslinux)
- [AppImage](#appimage)
- [Static Binary Distribution](#static-binary-distribution)
- [Packaging Checklist](#packaging-checklist)

---

## Overview

imtools is designed to be easy to package:

- **Single source file** - Just `src/main.zig` and `build.zig`
- **No runtime dependencies** - Core functionality is self-contained
- **Optional dependencies** - ffmpeg, curl, ollama for specific features
- **Cross-platform** - Zig handles cross-compilation

### Build Requirements

| Requirement | Version | Notes |
|-------------|---------|-------|
| Zig | 0.13+ | Build-time only |

### Optional Runtime Dependencies

| Package | Features |
|---------|----------|
| ffmpeg | `convert-to-png`, `download` |
| curl | `download`, `sort` |
| ollama | `sort` |

---

## Gentoo (Ebuild)

Two ebuilds are provided:

### Stable Ebuild (imtools-1.0.0.ebuild)

For tagged releases. Place in your local overlay:

```bash
# Create overlay structure (if not exists)
sudo mkdir -p /var/db/repos/local/{metadata,profiles,media-gfx/imtools}
echo "local" | sudo tee /var/db/repos/local/profiles/repo_name
echo "masters = gentoo" | sudo tee /var/db/repos/local/metadata/layout.conf

# Register overlay
sudo mkdir -p /etc/portage/repos.conf
cat <<EOF | sudo tee /etc/portage/repos.conf/local.conf
[local]
location = /var/db/repos/local
EOF
```

**Ebuild content:**

```bash
# /var/db/repos/local/media-gfx/imtools/imtools-1.0.0.ebuild

# Copyright 2024 4cecoder
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="Fast image manipulation CLI tool written in Zig"
HOMEPAGE="https://github.com/4cecoder/imtools"
SRC_URI="https://github.com/4cecoder/imtools/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86 ~arm64"
IUSE="+ffmpeg +curl ollama"

BDEPEND="dev-lang/zig"
RDEPEND="
    ffmpeg? ( media-video/ffmpeg )
    curl? ( net-misc/curl )
    ollama? ( app-misc/ollama )
"

src_compile() {
    zig build -Doptimize=ReleaseSafe || die "Build failed"
}

src_install() {
    dobin zig-out/bin/imtools
    dodoc README.md
    dodoc -r docs/
}
```

**Installation:**

```bash
# Copy ebuild to overlay
sudo cp imtools-1.0.0.ebuild /var/db/repos/local/media-gfx/imtools/

# Generate manifest
cd /var/db/repos/local/media-gfx/imtools
sudo ebuild imtools-1.0.0.ebuild manifest

# Install
sudo emerge --ask media-gfx/imtools
```

### Live Ebuild (imtools-9999.ebuild)

For git master:

```bash
# Copyright 2024 4cecoder
# Distributed under the terms of the MIT License

EAPI=8

inherit git-r3

DESCRIPTION="Fast image manipulation CLI tool written in Zig"
HOMEPAGE="https://github.com/4cecoder/imtools"
EGIT_REPO_URI="https://github.com/4cecoder/imtools.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS=""
IUSE="+ffmpeg +curl ollama"

BDEPEND="dev-lang/zig"
RDEPEND="
    ffmpeg? ( media-video/ffmpeg )
    curl? ( net-misc/curl )
    ollama? ( app-misc/ollama )
"

src_compile() {
    zig build -Doptimize=ReleaseSafe || die "Build failed"
}

src_install() {
    dobin zig-out/bin/imtools
    dodoc README.md
    insinto /usr/share/doc/${PF}
    doins -r docs/
}
```

---

## Arch Linux (PKGBUILD)

Create `PKGBUILD`:

```bash
# Maintainer: Your Name <your@email.com>
pkgname=imtools
pkgver=1.0.0
pkgrel=1
pkgdesc="Fast image manipulation CLI tool written in Zig"
arch=('x86_64' 'aarch64')
url="https://github.com/4cecoder/imtools"
license=('MIT')
makedepends=('zig')
optdepends=(
    'ffmpeg: for convert-to-png and download commands'
    'curl: for download and sort commands'
    'ollama: for AI-powered image sorting'
)
source=("$pkgname-$pkgver.tar.gz::https://github.com/4cecoder/imtools/archive/v$pkgver.tar.gz")
sha256sums=('SKIP')  # Replace with actual checksum

build() {
    cd "$pkgname-$pkgver"
    zig build -Doptimize=ReleaseSafe
}

package() {
    cd "$pkgname-$pkgver"
    install -Dm755 zig-out/bin/imtools "$pkgdir/usr/bin/imtools"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"

    # Install docs
    install -d "$pkgdir/usr/share/doc/$pkgname/docs"
    cp -r docs/* "$pkgdir/usr/share/doc/$pkgname/docs/"
}
```

**Build and install:**

```bash
makepkg -si
```

**Submit to AUR:**

```bash
# Create .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# Push to AUR
git clone ssh://aur@aur.archlinux.org/imtools.git
cp PKGBUILD .SRCINFO imtools/
cd imtools
git add PKGBUILD .SRCINFO
git commit -m "Initial upload"
git push
```

---

## Debian/Ubuntu (.deb)

### Using checkinstall (Quick)

```bash
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe
sudo checkinstall --pkgname=imtools --pkgversion=1.0.0 \
    --pakdir=. --backup=no --install=no \
    cp zig-out/bin/imtools /usr/local/bin/
```

### Proper Debian Package

Create package structure:

```bash
mkdir -p imtools-1.0.0/DEBIAN
mkdir -p imtools-1.0.0/usr/bin
mkdir -p imtools-1.0.0/usr/share/doc/imtools
```

**DEBIAN/control:**

```
Package: imtools
Version: 1.0.0
Section: graphics
Priority: optional
Architecture: amd64
Depends:
Recommends: ffmpeg, curl
Suggests: ollama
Maintainer: Your Name <your@email.com>
Description: Fast image manipulation CLI tool
 A Zig-based CLI tool for wallpaper and image management.
 Features include duplicate detection, format conversion,
 and AI-powered image sorting via Ollama.
```

**Build:**

```bash
# Build binary
zig build -Doptimize=ReleaseSafe

# Copy files
cp zig-out/bin/imtools imtools-1.0.0/usr/bin/
cp README.md LICENSE imtools-1.0.0/usr/share/doc/imtools/
cp -r docs imtools-1.0.0/usr/share/doc/imtools/

# Set permissions
chmod 755 imtools-1.0.0/usr/bin/imtools

# Build package
dpkg-deb --build imtools-1.0.0
```

---

## Fedora/RHEL (RPM)

Create `imtools.spec`:

```spec
Name:           imtools
Version:        1.0.0
Release:        1%{?dist}
Summary:        Fast image manipulation CLI tool written in Zig

License:        MIT
URL:            https://github.com/4cecoder/imtools
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:  zig >= 0.13

Recommends:     ffmpeg
Recommends:     curl
Suggests:       ollama

%description
A fast Zig-based CLI tool for wallpaper and image management.
Features duplicate detection, batch format conversion, wallpaper
downloading, and AI-powered image sorting via Ollama.

%prep
%autosetup

%build
zig build -Doptimize=ReleaseSafe

%install
install -Dm755 zig-out/bin/imtools %{buildroot}%{_bindir}/imtools
install -Dm644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE
install -Dm644 README.md %{buildroot}%{_docdir}/%{name}/README.md
cp -r docs %{buildroot}%{_docdir}/%{name}/

%files
%license LICENSE
%doc README.md docs/
%{_bindir}/imtools

%changelog
* Sun Dec 15 2024 Your Name <your@email.com> - 1.0.0-1
- Initial package
```

**Build:**

```bash
rpmbuild -ba imtools.spec
```

---

## Nix (Flake)

Create `flake.nix`:

```nix
{
  description = "Fast image manipulation CLI tool written in Zig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, zig }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zigPkg = zig.packages.${system}.master;
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "imtools";
          version = "1.0.0";

          src = ./.;

          nativeBuildInputs = [ zigPkg ];

          buildPhase = ''
            zig build -Doptimize=ReleaseSafe
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp zig-out/bin/imtools $out/bin/
          '';

          meta = with pkgs.lib; {
            description = "Fast image manipulation CLI tool";
            homepage = "https://github.com/4cecoder/imtools";
            license = licenses.mit;
            platforms = platforms.linux ++ platforms.darwin;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ zigPkg pkgs.ffmpeg pkgs.curl ];
        };
      }
    );
}
```

**Usage:**

```bash
# Build
nix build

# Run
nix run

# Development shell
nix develop
```

---

## Homebrew (macOS/Linux)

Create formula `imtools.rb`:

```ruby
class Imtools < Formula
  desc "Fast image manipulation CLI tool written in Zig"
  homepage "https://github.com/4cecoder/imtools"
  url "https://github.com/4cecoder/imtools/archive/v1.0.0.tar.gz"
  sha256 "CHECKSUM_HERE"
  license "MIT"

  depends_on "zig" => :build

  def install
    system "zig", "build", "-Doptimize=ReleaseSafe"
    bin.install "zig-out/bin/imtools"
    doc.install "README.md"
    doc.install Dir["docs/*"]
  end

  test do
    system "#{bin}/imtools", "help"
  end
end
```

**Submit to Homebrew:**

```bash
# Test locally
brew install --build-from-source ./imtools.rb

# Create tap
# Push to github.com/yourusername/homebrew-tap
```

---

## AppImage

For portable Linux distribution:

```bash
# Create AppDir structure
mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/share/applications
mkdir -p AppDir/usr/share/icons/hicolor/256x256/apps

# Build
zig build -Doptimize=ReleaseSafe
cp zig-out/bin/imtools AppDir/usr/bin/

# Create .desktop file
cat > AppDir/imtools.desktop <<EOF
[Desktop Entry]
Type=Application
Name=imtools
Exec=imtools
Icon=imtools
Categories=Graphics;
Terminal=true
EOF

# Create AppRun
cat > AppDir/AppRun <<EOF
#!/bin/bash
exec "\$APPDIR/usr/bin/imtools" "\$@"
EOF
chmod +x AppDir/AppRun

# Build AppImage (requires appimagetool)
ARCH=x86_64 appimagetool AppDir
```

---

## Static Binary Distribution

Zig makes it easy to create fully static binaries:

```bash
# Build static binary
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl

# The binary in zig-out/bin/imtools is now fully static
ldd zig-out/bin/imtools  # Should show "not a dynamic executable"
```

**Cross-compilation targets:**

```bash
# Linux ARM64
zig build -Doptimize=ReleaseSafe -Dtarget=aarch64-linux-musl

# macOS x86_64
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-macos

# macOS ARM64 (Apple Silicon)
zig build -Doptimize=ReleaseSafe -Dtarget=aarch64-macos

# Windows x86_64
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-windows
```

---

## Packaging Checklist

When creating a package for a new distribution:

### Required Files

- [ ] Binary: `imtools` (or `imtools.exe` on Windows)
- [ ] License: `LICENSE` (MIT)
- [ ] Documentation: `README.md`
- [ ] Detailed docs: `docs/` directory

### Metadata

- [ ] Package name: `imtools`
- [ ] Version: Match git tag (e.g., `1.0.0`)
- [ ] Description: "Fast image manipulation CLI tool written in Zig"
- [ ] License: MIT
- [ ] Homepage: https://github.com/4cecoder/imtools
- [ ] Categories: Graphics, Utility, CLI

### Dependencies

- [ ] Build: `zig >= 0.13`
- [ ] Runtime (optional): `ffmpeg`, `curl`
- [ ] Runtime (optional): `ollama`

### Installation Paths

| File | Typical Path |
|------|--------------|
| Binary | `/usr/bin/imtools` or `/usr/local/bin/imtools` |
| License | `/usr/share/licenses/imtools/LICENSE` |
| Docs | `/usr/share/doc/imtools/` |

### Testing

After installation, verify:

```bash
imtools help                    # Basic functionality
imtools flatten --dry-run       # Directory operations
imtools find-duplicates         # Hashing
which ffmpeg && imtools convert-to-png --dry-run  # ffmpeg integration
```

---

## Need Help?

- Open an issue on [GitHub](https://github.com/4cecoder/imtools/issues)
- Check existing packages for reference
- See [Architecture Guide](architecture.md) for build details
