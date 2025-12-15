<div align="center">

# imtools

[![CI](https://github.com/4cecoder/imtools/actions/workflows/ci.yml/badge.svg)](https://github.com/4cecoder/imtools/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/4cecoder/imtools?include_prereleases)](https://github.com/4cecoder/imtools/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zig](https://img.shields.io/badge/Zig-0.13+-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)

**Fast image manipulation CLI written in Zig**

[Features](#features) • [Install](#quick-start) • [Commands](#commands) • [Docs](#documentation)

</div>

---

A fast, standalone CLI tool for image and wallpaper management. Written in Zig with zero runtime dependencies for core operations.

```bash
# Flatten nested folders
imtools flatten

# Find and remove duplicates
imtools find-duplicates --delete

# AI-powered sorting (via Ollama)
imtools sort --categories "nature,anime,abstract,city"
```

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [Documentation](#documentation)
- [Why Zig?](#why-zig)
- [License](#license)

---

## Features

| Feature | Description |
|---------|-------------|
| **Flatten** | Move all images from nested subdirectories to one place |
| **Duplicates** | Find identical images via SHA256 hash comparison |
| **Portrait Filter** | Delete portrait-oriented images (height > width) |
| **Format Convert** | Batch convert images to PNG via ffmpeg |
| **Download** | Fetch wallpapers from wallhaven.cc |
| **AI Sort** | Categorize images using local Ollama vision models |

**Supported formats:** PNG, JPEG, GIF, BMP, WebP, TIFF

---

## Quick Start

### Install

```bash
# Requires Zig 0.13+
git clone https://github.com/4cecoder/imtools.git
cd imtools
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/imtools /usr/local/bin/
```

See [Installation Guide](docs/installation.md) for platform-specific instructions.

### Basic Usage

```bash
cd ~/wallpapers

# Preview changes first (always safe)
imtools flatten --dry-run
imtools delete-portrait --dry-run

# Execute
imtools flatten
imtools find-duplicates --delete
imtools remove-empty-dirs
```

---

## Commands

| Command | Description | Requires |
|---------|-------------|----------|
| `flatten` | Move images from subdirs to current dir | - |
| `find-duplicates` | Find duplicate images by SHA256 | - |
| `delete-portrait` | Delete portrait images | - |
| `remove-empty-dirs` | Remove empty directories | - |
| `convert-to-png` | Convert images to PNG | ffmpeg |
| `download` | Download from wallhaven.cc | curl, ffmpeg |
| `sort` | AI categorization | curl, ollama |

### Examples

```bash
# Download 50 nature wallpapers
imtools download --query "nature landscape" --limit 50

# Convert all to PNG, delete originals
imtools convert-to-png --delete

# AI sort with custom categories
imtools sort --categories "mountains,ocean,forest,anime,abstract"

# AI sort with specific model
imtools sort --model llava:7b --workers 4
```

Full command reference: [docs/commands.md](docs/commands.md)

---

## Documentation

| Document | Description |
|----------|-------------|
| [Installation](docs/installation.md) | Setup for Linux, macOS, Windows |
| [Commands](docs/commands.md) | Complete command reference with examples |
| [AI Sorting](docs/ai-sorting.md) | Ollama setup, model selection, tuning |
| [Architecture](docs/architecture.md) | Code structure, contributing guide |
| [Packaging](docs/packaging.md) | Create packages for any distro |

---

## Why Zig?

- **Fast startup** - No runtime, no GC, instant execution
- **Single binary** - No dependencies to manage
- **Cross-compile** - Build for any platform from any platform
- **Low memory** - Efficient image header parsing without loading full images
- **Easy to read** - Simple, explicit code

---

## Optional Dependencies

Core commands (`flatten`, `find-duplicates`, `delete-portrait`, `remove-empty-dirs`) need nothing but the binary.

For extended features:

| Dependency | Commands | Install |
|------------|----------|---------|
| ffmpeg | `convert-to-png`, `download` | `apt install ffmpeg` |
| curl | `download`, `sort` | Usually pre-installed |
| ollama | `sort` | [ollama.ai](https://ollama.ai) |

---

## License

MIT - see [LICENSE](LICENSE)

---

## Contributing

Contributions welcome! See [Architecture Guide](docs/architecture.md) for:
- Code structure overview
- Adding new commands
- Adding image format support
- Testing guidelines

---

## Links

- [GitHub](https://github.com/4cecoder/imtools)
- [Zig Language](https://ziglang.org)
- [Ollama](https://ollama.ai)
- [wallhaven.cc](https://wallhaven.cc)
