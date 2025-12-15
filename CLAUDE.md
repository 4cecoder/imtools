# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build
zig build

# Build optimized
zig build -Doptimize=ReleaseSafe

# Run directly without installing
./zig-out/bin/imtools help

# Run with arguments
zig build run -- flatten --dry-run
```

## Architecture

Single-file Zig CLI tool (`src/main.zig`) with these major components:

- **ImageType enum**: File extension detection for PNG, JPEG, GIF, BMP, WebP, TIFF
- **Image header parsing**: Native binary parsing to read dimensions from image headers (no external libs)
- **Commands**: Each command is a standalone function (flattenImages, findDuplicates, deletePortraitImages, etc.)
- **External tool integration**: Uses `curl` for downloads, `ffmpeg` for conversions, `ollama` for AI sorting

**Key functions:**
- `getImageDimensions()` - Parses image headers to extract width/height
- `downloadWallpapers()` - Scrapes wallhaven.cc and downloads images
- `sortImages()` - AI-powered categorization via Ollama vision models
- `convertToPng()` - Batch conversion using ffmpeg

## External Dependencies

- **ffmpeg**: Required for `convert-to-png` and `download` commands
- **curl**: Required for `download` and `sort` commands
- **ollama**: Required for `sort` command (AI image categorization)

## Process Exit Code Handling

When checking subprocess results in Zig, use proper tagged union access:
```zig
const success = switch (result.term) {
    .Exited => |code| code == 0,
    else => false,
};
```
Do NOT use `result.term.Exited` directly - it will fail at runtime.
