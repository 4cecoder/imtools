# Installation Guide

Complete installation instructions for all supported platforms.

## Table of Contents

- [Requirements](#requirements)
- [Quick Install](#quick-install)
- [Building from Source](#building-from-source)
- [Platform-Specific Instructions](#platform-specific-instructions)
  - [Linux](#linux)
  - [macOS](#macos)
  - [Windows](#windows)
- [Optional Dependencies](#optional-dependencies)
- [Verifying Installation](#verifying-installation)

---

## Requirements

### Build Requirements

| Requirement | Version | Notes |
|-------------|---------|-------|
| Zig | 0.13+ | [Download Zig](https://ziglang.org/download/) |

### Runtime Requirements (Optional)

These are only needed for specific commands:

| Dependency | Required For | Install |
|------------|--------------|---------|
| ffmpeg | `convert-to-png`, `download` | Package manager |
| curl | `download`, `sort` | Usually pre-installed |
| ollama | `sort` | [ollama.ai](https://ollama.ai) |

---

## Quick Install

```bash
# Clone and build
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe

# Install to PATH
cp zig-out/bin/imtools ~/.local/bin/
# or system-wide:
sudo cp zig-out/bin/imtools /usr/local/bin/
```

---

## Building from Source

### Debug Build (faster compilation)

```bash
zig build
./zig-out/bin/imtools help
```

### Release Build (optimized binary)

```bash
zig build -Doptimize=ReleaseSafe
```

### Build Options

| Flag | Description |
|------|-------------|
| `-Doptimize=Debug` | Debug build with symbols (default) |
| `-Doptimize=ReleaseSafe` | Optimized with safety checks |
| `-Doptimize=ReleaseFast` | Maximum optimization |
| `-Doptimize=ReleaseSmall` | Optimize for binary size |

---

## Platform-Specific Instructions

### Linux

#### Ubuntu/Debian

```bash
# Install Zig
sudo snap install zig --classic --beta
# Or download from ziglang.org

# Install optional dependencies
sudo apt install ffmpeg curl

# Build imtools
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/imtools /usr/local/bin/
```

#### Fedora/RHEL

```bash
# Install Zig (download from ziglang.org recommended)
# Install optional dependencies
sudo dnf install ffmpeg curl

# Build imtools
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/imtools /usr/local/bin/
```

#### Arch Linux

```bash
# Install Zig and dependencies
sudo pacman -S zig ffmpeg curl

# Build imtools
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/imtools /usr/local/bin/
```

#### Gentoo

See [Packaging Guide](packaging.md#gentoo-ebuild) for ebuild installation.

```bash
# Quick manual install
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/imtools /usr/local/bin/
```

#### NixOS

```bash
# In a nix-shell with zig
nix-shell -p zig
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe
cp zig-out/bin/imtools ~/.local/bin/
```

### macOS

```bash
# Install Zig via Homebrew
brew install zig

# Install optional dependencies
brew install ffmpeg curl

# Build imtools
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe
cp zig-out/bin/imtools /usr/local/bin/
```

### Windows

```powershell
# Install Zig (download from ziglang.org or use scoop/chocolatey)
scoop install zig
# or
choco install zig

# Clone and build
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe

# Add to PATH or copy to a directory in PATH
copy zig-out\bin\imtools.exe C:\Users\%USERNAME%\bin\
```

---

## Optional Dependencies

### ffmpeg

Required for: `convert-to-png`, `download`

| Platform | Install Command |
|----------|-----------------|
| Ubuntu/Debian | `sudo apt install ffmpeg` |
| Fedora | `sudo dnf install ffmpeg` |
| Arch | `sudo pacman -S ffmpeg` |
| Gentoo | `sudo emerge media-video/ffmpeg` |
| macOS | `brew install ffmpeg` |
| Windows | `choco install ffmpeg` or [download](https://ffmpeg.org/download.html) |

### Ollama

Required for: `sort` (AI-powered image categorization)

```bash
# Linux/macOS
curl -fsSL https://ollama.ai/install.sh | sh

# Start the service
ollama serve

# Pull a vision model
ollama pull moondream:1.8b
```

See [AI Sorting Guide](ai-sorting.md) for detailed Ollama setup.

---

## Verifying Installation

```bash
# Check imtools is installed
imtools help

# Check version (via help output)
imtools help | head -5

# Test basic functionality
mkdir test-images
cd test-images
# Add some test images...
imtools flatten --dry-run
```

### Verify Optional Dependencies

```bash
# Check ffmpeg
ffmpeg -version

# Check curl
curl --version

# Check Ollama
ollama --version
curl -s http://localhost:11434/api/tags  # Should return JSON if running
```

---

## Troubleshooting

### "zig: command not found"

Ensure Zig is in your PATH:

```bash
# Check if zig is installed
which zig

# Add to PATH if needed (add to ~/.bashrc or ~/.zshrc)
export PATH="$PATH:$HOME/zig"
```

### "Permission denied" when installing

Use `sudo` for system-wide installation, or install to user directory:

```bash
mkdir -p ~/.local/bin
cp zig-out/bin/imtools ~/.local/bin/
# Add to PATH if not already
export PATH="$PATH:$HOME/.local/bin"
```

### Build fails with Zig version error

Ensure you have Zig 0.13 or later:

```bash
zig version
# Should show 0.13.0 or higher
```

---

## Next Steps

- [Command Reference](commands.md) - Learn all available commands
- [AI Sorting Guide](ai-sorting.md) - Set up AI-powered image categorization
- [Packaging Guide](packaging.md) - Create packages for your distribution
