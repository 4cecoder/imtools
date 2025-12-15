# Architecture & Contributing

Understanding imtools internals for contributors and maintainers.

## Table of Contents

- [Project Structure](#project-structure)
- [Design Philosophy](#design-philosophy)
- [Code Architecture](#code-architecture)
  - [Image Format Detection](#image-format-detection)
  - [Dimension Parsing](#dimension-parsing)
  - [Command Pattern](#command-pattern)
  - [External Tool Integration](#external-tool-integration)
- [Adding a New Command](#adding-a-new-command)
- [Adding Image Format Support](#adding-image-format-support)
- [Testing](#testing)
- [Contributing Guidelines](#contributing-guidelines)

---

## Project Structure

```
imtools/
├── src/
│   └── main.zig          # Single-file implementation (~1900 lines)
├── docs/
│   ├── installation.md   # Installation guide
│   ├── commands.md       # Command reference
│   ├── architecture.md   # This file
│   ├── packaging.md      # Packaging guide
│   └── ai-sorting.md     # AI sorting guide
├── build.zig             # Zig build configuration
├── imtools-1.0.0.ebuild  # Gentoo stable ebuild
├── imtools-9999.ebuild   # Gentoo live ebuild
├── README.md             # Project overview
├── CLAUDE.md             # AI assistant context
├── LICENSE               # MIT license
└── .gitignore
```

---

## Design Philosophy

### Single-File Architecture

imtools is intentionally a single-file Zig program. This provides:

1. **Simplicity** - Easy to understand the entire codebase
2. **Portability** - No complex build systems or dependencies
3. **Fast Compilation** - Single compilation unit
4. **Easy Distribution** - One source file to share

### No External Libraries for Core Functions

Image dimension parsing is implemented natively by reading binary headers:

- **Why?** Avoids dependency on ImageMagick, libpng, libjpeg, etc.
- **Trade-off:** Only extracts dimensions, not full image decoding
- **Benefit:** Extremely fast, no library compatibility issues

### External Tools for Complex Operations

For operations requiring full image processing:

- **ffmpeg** - Image format conversion (battle-tested, universal)
- **curl** - HTTP requests (reliable, widely available)
- **ollama** - AI vision (local, privacy-preserving)

---

## Code Architecture

### Image Format Detection

```zig
const ImageType = enum {
    png,
    jpeg,
    gif,
    bmp,
    webp,
    tiff,
    unknown,

    fn fromExtension(ext: []const u8) ImageType {
        // Case-insensitive extension matching
    }

    fn isImage(filename: []const u8) bool {
        // Check if file has image extension
    }
};
```

**Key insight:** Extension-based detection is used for filtering, but actual format is verified when reading headers.

### Dimension Parsing

Each format has specific header parsing:

```zig
fn getImageDimensions(allocator: mem.Allocator, file_path: []const u8) !ImageDimensions {
    // Read first 512 bytes (sufficient for all format headers)
    var header_buf: [512]u8 = undefined;
    const bytes_read = try file.read(&header_buf);

    // PNG: Dimensions at bytes 16-23 after 8-byte signature
    if (mem.eql(u8, header[0..8], &[_]u8{ 0x89, 0x50, 0x4E, 0x47, ... })) {
        const width = readU32BE(header, 16);
        const height = readU32BE(header, 20);
        return ImageDimensions{ .width = width, .height = height };
    }

    // JPEG: Scan for SOF0/SOF2 markers
    // GIF: Dimensions at bytes 6-9
    // BMP: Dimensions at bytes 18-25
    // WebP: Multiple chunk formats (VP8, VP8L, VP8X)
    // ...
}
```

**Binary reading helpers:**

```zig
fn readU16BE(data: []const u8, offset: usize) u16  // Big-endian
fn readU32BE(data: []const u8, offset: usize) u32
fn readU16LE(data: []const u8, offset: usize) u16  // Little-endian
fn readU32LE(data: []const u8, offset: usize) u32
```

### Command Pattern

Each command is a standalone function:

```zig
fn flattenImages(allocator: mem.Allocator, dry_run: bool) !void
fn findDuplicates(allocator: mem.Allocator, delete_mode: bool) !void
fn deletePortraitImages(allocator: mem.Allocator, dry_run: bool) !void
fn removeEmptyDirs(allocator: mem.Allocator, dry_run: bool) !void
fn convertToPng(allocator: mem.Allocator, dry_run: bool, delete_original: bool) !void
fn downloadWallpapers(allocator: mem.Allocator, query: []const u8, limit: usize, output_dir: []const u8) !void
fn sortImages(allocator: mem.Allocator, config: SortConfig) !void
```

**Common patterns:**

1. Open current directory with walker
2. Filter for image files
3. Process each file
4. Track counts (processed, errors, skipped)
5. Print summary

### External Tool Integration

Subprocess execution pattern:

```zig
const result = std.process.Child.run(.{
    .allocator = allocator,
    .argv = &[_][]const u8{ "ffmpeg", "-i", input, "-y", output },
    .max_output_bytes = 64 * 1024,
}) catch |err| {
    // Handle spawn error
};
defer allocator.free(result.stdout);
defer allocator.free(result.stderr);

// Check exit code properly (tagged union)
const success = switch (result.term) {
    .Exited => |code| code == 0,
    else => false,
};
```

**Important:** Never use `result.term.Exited` directly - it's a tagged union and will fail at runtime.

---

## Adding a New Command

### 1. Add Command Function

```zig
fn myNewCommand(allocator: mem.Allocator, some_option: bool) !void {
    std.debug.print("Running my new command...\n", .{});

    var dir = try fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!ImageType.isImage(entry.basename)) continue;

        // Your logic here
    }

    std.debug.print("\nDone!\n", .{});
}
```

### 2. Add to Help Text

```zig
fn printUsage() void {
    std.debug.print(
        \\...
        \\  my-command          Description of my command
        \\...
    , .{});
}
```

### 3. Add Command Parsing in main()

```zig
} else if (mem.eql(u8, command, "my-command")) {
    try myNewCommand(allocator, some_option);
}
```

### 4. Add Options Parsing (if needed)

```zig
// In argument parsing loop
} else if (mem.eql(u8, arg, "--my-option")) {
    my_option = true;
}
```

---

## Adding Image Format Support

### 1. Add to ImageType enum

```zig
const ImageType = enum {
    png,
    jpeg,
    // ... existing
    avif,  // New format
    unknown,

    fn fromExtension(ext: []const u8) ImageType {
        // ... existing
        if (mem.eql(u8, lower, ".avif")) return .avif;
        return .unknown;
    }
};
```

### 2. Add Header Parsing

Research the format's binary structure and add to `getImageDimensions()`:

```zig
// AVIF: Based on ISOBMFF container
// (simplified - actual AVIF parsing is more complex)
if (bytes_read >= 12 and mem.eql(u8, header[4..12], "ftypavif")) {
    // Parse AVIF structure for dimensions
}
```

### 3. Add to convertToPng (if ffmpeg supports it)

Usually no changes needed - ffmpeg auto-detects input format.

---

## Testing

### Manual Testing

```bash
# Create test directory with sample images
mkdir test-images
cd test-images
# Add test images of various formats

# Test each command
../zig-out/bin/imtools flatten --dry-run
../zig-out/bin/imtools find-duplicates
../zig-out/bin/imtools delete-portrait --dry-run
```

### Test Edge Cases

- Empty directories
- Deeply nested directories
- Filenames with spaces and special characters
- Corrupted image headers
- Very large files
- Mixed image formats

---

## Contributing Guidelines

### Code Style

- Follow Zig standard library conventions
- Use descriptive variable names
- Add comments for complex logic
- Keep functions focused and single-purpose

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test thoroughly
5. Commit with clear messages
6. Push and create PR

### Commit Messages

```
Add AVIF format support

- Add .avif extension detection to ImageType
- Implement AVIF header parsing for dimensions
- Update documentation
```

### What We're Looking For

- New image format support
- Performance improvements
- Bug fixes
- Documentation improvements
- Packaging for new distributions

### What to Avoid

- Adding heavy dependencies
- Breaking single-file architecture (unless very compelling reason)
- Platform-specific code (keep cross-platform)

---

## Next Steps

- [Packaging Guide](packaging.md) - Create packages for your distribution
- [Command Reference](commands.md) - Understand all commands
