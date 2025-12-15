const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const crypto = std.crypto;
const base64 = std.base64.standard;

const ImageDimensions = struct {
    width: u32,
    height: u32,
};

const SortConfig = struct {
    dry_run: bool = false,
    recursive: bool = true,
    categories: ?[]const u8 = null,
    output_dir: []const u8 = ".",
    cooldown_ms: u64 = 500,
    model: []const u8 = DEFAULT_VISION_MODEL,
    workers: u32 = 2,
};

const OLLAMA_URL = "http://localhost:11434";
const DEFAULT_VISION_MODEL = "moondream:1.8b";

const ImageType = enum {
    png,
    jpeg,
    gif,
    bmp,
    webp,
    tiff,
    unknown,

    fn fromExtension(ext: []const u8) ImageType {
        var lower_buf: [16]u8 = undefined;
        const lower = std.ascii.lowerString(&lower_buf, ext);

        if (mem.eql(u8, lower, ".png")) return .png;
        if (mem.eql(u8, lower, ".jpg")) return .jpeg;
        if (mem.eql(u8, lower, ".jpeg")) return .jpeg;
        if (mem.eql(u8, lower, ".gif")) return .gif;
        if (mem.eql(u8, lower, ".bmp")) return .bmp;
        if (mem.eql(u8, lower, ".webp")) return .webp;
        if (mem.eql(u8, lower, ".tif")) return .tiff;
        if (mem.eql(u8, lower, ".tiff")) return .tiff;
        return .unknown;
    }

    fn isImage(filename: []const u8) bool {
        const ext_start = mem.lastIndexOfScalar(u8, filename, '.');
        if (ext_start == null) return false;
        const ext = filename[ext_start.?..];
        return fromExtension(ext) != .unknown;
    }
};

fn readU16BE(data: []const u8, offset: usize) u16 {
    return @as(u16, data[offset]) << 8 | @as(u16, data[offset + 1]);
}

fn readU32BE(data: []const u8, offset: usize) u32 {
    return @as(u32, data[offset]) << 24 | @as(u32, data[offset + 1]) << 16 | @as(u32, data[offset + 2]) << 8 | @as(u32, data[offset + 3]);
}

fn readU16LE(data: []const u8, offset: usize) u16 {
    return @as(u16, data[offset + 1]) << 8 | @as(u16, data[offset]);
}

fn readU32LE(data: []const u8, offset: usize) u32 {
    return @as(u32, data[offset + 3]) << 24 | @as(u32, data[offset + 2]) << 16 | @as(u32, data[offset + 1]) << 8 | @as(u32, data[offset]);
}

fn getImageDimensions(allocator: mem.Allocator, file_path: []const u8) !ImageDimensions {
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    var header_buf: [512]u8 = undefined;
    const bytes_read = try file.read(&header_buf);
    if (bytes_read < 16) return error.InvalidImage;

    const header = header_buf[0..bytes_read];

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes_read >= 24 and mem.eql(u8, header[0..8], &[_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })) {
        const width = readU32BE(header, 16);
        const height = readU32BE(header, 20);
        return ImageDimensions{ .width = width, .height = height };
    }

    // JPEG: FF D8 FF
    if (bytes_read >= 2 and header[0] == 0xFF and header[1] == 0xD8) {
        var offset: usize = 2;
        while (offset + 9 < bytes_read) {
            if (header[offset] != 0xFF) break;
            const marker = header[offset + 1];
            offset += 2;

            if (marker == 0xC0 or marker == 0xC2) {
                const height = readU16BE(header, offset + 3);
                const width = readU16BE(header, offset + 5);
                return ImageDimensions{ .width = width, .height = height };
            }

            if (marker == 0xD8 or marker == 0xD9 or marker == 0x01) continue;

            if (offset + 2 >= bytes_read) break;
            const segment_len = readU16BE(header, offset);
            offset += segment_len;
        }

        try file.seekTo(0);
        var buf = try allocator.alloc(u8, 65536);
        defer allocator.free(buf);
        const full_read = try file.read(buf);
        const full_data = buf[0..full_read];

        offset = 2;
        while (offset + 9 < full_read) {
            if (full_data[offset] != 0xFF) break;
            const marker = full_data[offset + 1];
            offset += 2;

            if (marker == 0xC0 or marker == 0xC2) {
                const height = readU16BE(full_data, offset + 3);
                const width = readU16BE(full_data, offset + 5);
                return ImageDimensions{ .width = width, .height = height };
            }

            if (marker == 0xD8 or marker == 0xD9 or marker == 0x01) continue;

            if (offset + 2 >= full_read) break;
            const segment_len = readU16BE(full_data, offset);
            offset += segment_len;
        }
        return error.InvalidImage;
    }

    // GIF: GIF87a or GIF89a
    if (bytes_read >= 10 and (mem.eql(u8, header[0..6], "GIF87a") or mem.eql(u8, header[0..6], "GIF89a"))) {
        const width = readU16LE(header, 6);
        const height = readU16LE(header, 8);
        return ImageDimensions{ .width = width, .height = height };
    }

    // BMP: BM
    if (bytes_read >= 26 and header[0] == 'B' and header[1] == 'M') {
        const width = readU32LE(header, 18);
        const height = readU32LE(header, 22);
        return ImageDimensions{ .width = width, .height = height };
    }

    // WebP: RIFF....WEBP
    if (bytes_read >= 30 and mem.eql(u8, header[0..4], "RIFF") and mem.eql(u8, header[8..12], "WEBP")) {
        if (mem.eql(u8, header[12..16], "VP8 ")) {
            const width = readU16LE(header, 26) & 0x3FFF;
            const height = readU16LE(header, 28) & 0x3FFF;
            return ImageDimensions{ .width = width, .height = height };
        } else if (mem.eql(u8, header[12..16], "VP8L")) {
            const bits = readU32LE(header, 21);
            const width = (bits & 0x3FFF) + 1;
            const height = ((bits >> 14) & 0x3FFF) + 1;
            return ImageDimensions{ .width = width, .height = height };
        } else if (mem.eql(u8, header[12..16], "VP8X")) {
            const width = (readU32LE(header, 24) & 0xFFFFFF) + 1;
            const height = (readU32LE(header, 27) & 0xFFFFFF) + 1;
            return ImageDimensions{ .width = width, .height = height };
        }
    }

    // TIFF: II (little-endian) or MM (big-endian)
    if (bytes_read >= 8) {
        const is_little = mem.eql(u8, header[0..2], "II");
        const is_big = mem.eql(u8, header[0..2], "MM");
        if (is_little or is_big) {
            return error.TIFFNotFullySupported;
        }
    }

    return error.UnknownImageFormat;
}

fn flattenImages(allocator: mem.Allocator, dry_run: bool) !void {
    std.debug.print("Flattening image files to current directory...\n", .{});
    if (dry_run) {
        std.debug.print("DRY RUN MODE - No files will be moved\n\n", .{});
    }

    var dir = try fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var moved_count: usize = 0;
    var error_count: usize = 0;

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!ImageType.isImage(entry.basename)) continue;

        const depth = mem.count(u8, entry.path, "/");
        if (depth == 0) continue;

        const dest_path = entry.basename;

        if (dry_run) {
            std.debug.print("Would move: {s} -> {s}\n", .{ entry.path, dest_path });
            moved_count += 1;
        } else {
            dir.rename(entry.path, dest_path) catch |err| {
                std.debug.print("Error moving {s}: {}\n", .{ entry.path, err });
                error_count += 1;
                continue;
            };
            std.debug.print("Moved: {s} -> {s}\n", .{ entry.path, dest_path });
            moved_count += 1;
        }
    }

    std.debug.print("\nSummary:\n", .{});
    std.debug.print("Files moved: {d}\n", .{moved_count});
    if (error_count > 0) {
        std.debug.print("Errors: {d}\n", .{error_count});
    }
}

fn findDuplicates(allocator: mem.Allocator, delete_mode: bool) !void {
    std.debug.print("Finding duplicate images by SHA256 hash...\n\n", .{});

    var dir = try fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var hash_map = std.StringHashMap(std.ArrayList([]const u8)).init(allocator);
    defer {
        var it = hash_map.iterator();
        while (it.next()) |entry| {
            for (entry.value_ptr.items) |path| {
                allocator.free(path);
            }
            entry.value_ptr.deinit(allocator);
            allocator.free(entry.key_ptr.*);
        }
        hash_map.deinit();
    }

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var file_count: usize = 0;
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!ImageType.isImage(entry.basename)) continue;

        file_count += 1;

        const file = dir.openFile(entry.path, .{}) catch |err| {
            std.debug.print("Error opening {s}: {}\n", .{ entry.path, err });
            continue;
        };
        defer file.close();

        const file_stat = file.stat() catch |err| {
            std.debug.print("Error stating {s}: {}\n", .{ entry.path, err });
            continue;
        };
        const file_size = file_stat.size;

        const file_data = allocator.alloc(u8, file_size) catch |err| {
            std.debug.print("Error allocating for {s}: {}\n", .{ entry.path, err });
            continue;
        };
        defer allocator.free(file_data);

        const bytes_read = file.preadAll(file_data, 0) catch |err| {
            std.debug.print("Error reading {s}: {}\n", .{ entry.path, err });
            continue;
        };
        if (bytes_read != file_size) {
            std.debug.print("Incomplete read for {s}\n", .{entry.path});
            continue;
        }

        var hash: [32]u8 = undefined;
        crypto.hash.sha2.Sha256.hash(file_data, &hash, .{});

        var hash_hex: [64]u8 = undefined;
        const hex_chars = "0123456789abcdef";
        for (hash, 0..) |byte, i| {
            hash_hex[i * 2] = hex_chars[byte >> 4];
            hash_hex[i * 2 + 1] = hex_chars[byte & 0x0F];
        }

        const gop = try hash_map.getOrPut(hash_hex[0..64]);
        if (!gop.found_existing) {
            const hash_copy = try allocator.dupe(u8, hash_hex[0..64]);
            gop.key_ptr.* = hash_copy;
            gop.value_ptr.* = .empty;
        }

        const path_copy = try allocator.dupe(u8, entry.path);
        try gop.value_ptr.append(allocator, path_copy);
    }

    std.debug.print("Scanned {d} image files\n\n", .{file_count});

    var found_duplicates = false;
    var duplicate_groups: usize = 0;
    var it = hash_map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.items.len <= 1) continue;

        found_duplicates = true;
        duplicate_groups += 1;

        std.debug.print("Duplicate group (hash: {s}):\n", .{entry.key_ptr.*[0..16]});
        for (entry.value_ptr.items, 0..) |path, i| {
            std.debug.print("  [{d}] {s}\n", .{ i, path });
        }

        if (delete_mode) {
            std.debug.print("Delete duplicates? Keep first file. [y/N]: ", .{});

            var buf: [16]u8 = undefined;
            const bytes_read = try fs.File.stdin().read(&buf);
            const input = buf[0..bytes_read];
            const trimmed = mem.trim(u8, input, &std.ascii.whitespace);

            if (mem.eql(u8, trimmed, "y") or mem.eql(u8, trimmed, "Y")) {
                for (entry.value_ptr.items[1..]) |path| {
                    dir.deleteFile(path) catch |err| {
                        std.debug.print("  Error deleting {s}: {}\n", .{ path, err });
                        continue;
                    };
                    std.debug.print("  Deleted: {s}\n", .{path});
                }
            }
        }
        std.debug.print("\n", .{});
    }

    if (!found_duplicates) {
        std.debug.print("No duplicate images found.\n", .{});
    } else {
        std.debug.print("Found {d} duplicate groups.\n", .{duplicate_groups});
    }
}

fn deletePortraitImages(allocator: mem.Allocator, dry_run: bool) !void {
    std.debug.print("Searching for portrait images (height > width)...\n", .{});
    if (dry_run) {
        std.debug.print("DRY RUN MODE - No files will be deleted\n\n", .{});
    }

    var dir = try fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var portrait_count: usize = 0;
    var deleted_count: usize = 0;
    var error_count: usize = 0;

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!ImageType.isImage(entry.basename)) continue;

        const dims = getImageDimensions(allocator, entry.path) catch |err| {
            std.debug.print("Error reading {s}: {}\n", .{ entry.path, err });
            error_count += 1;
            continue;
        };

        if (dims.height > dims.width) {
            portrait_count += 1;
            std.debug.print("Portrait image: {s} ({d}x{d})\n", .{ entry.path, dims.width, dims.height });

            if (!dry_run) {
                dir.deleteFile(entry.path) catch |err| {
                    std.debug.print("  Error deleting: {}\n", .{err});
                    error_count += 1;
                    continue;
                };
                std.debug.print("  Deleted\n", .{});
                deleted_count += 1;
            }
        }
    }

    std.debug.print("\n==============================\n", .{});
    std.debug.print("Summary:\n", .{});
    std.debug.print("==============================\n", .{});
    std.debug.print("Portrait images found: {d}\n", .{portrait_count});
    if (!dry_run) {
        std.debug.print("Successfully deleted: {d}\n", .{deleted_count});
    }
    if (error_count > 0) {
        std.debug.print("Errors encountered: {d}\n", .{error_count});
    }
    if (dry_run and portrait_count > 0) {
        std.debug.print("\nThis was a dry run. Run without --dry-run to actually delete files.\n", .{});
    }
}

fn convertToPng(allocator: mem.Allocator, dry_run: bool, delete_original: bool) !void {
    std.debug.print("Converting images to PNG format...\n", .{});
    if (dry_run) {
        std.debug.print("DRY RUN MODE - No files will be converted\n\n", .{});
    }

    var dir = try fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var converted_count: usize = 0;
    var skipped_count: usize = 0;
    var error_count: usize = 0;

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        const ext_start = mem.lastIndexOfScalar(u8, entry.basename, '.') orelse continue;
        const ext = entry.basename[ext_start..];

        var lower_buf: [16]u8 = undefined;
        const lower_ext = std.ascii.lowerString(&lower_buf, ext);

        // Skip if already PNG
        if (mem.eql(u8, lower_ext, ".png")) continue;

        // Only convert supported formats
        const is_convertible = mem.eql(u8, lower_ext, ".jpg") or
            mem.eql(u8, lower_ext, ".jpeg") or
            mem.eql(u8, lower_ext, ".gif") or
            mem.eql(u8, lower_ext, ".bmp") or
            mem.eql(u8, lower_ext, ".webp") or
            mem.eql(u8, lower_ext, ".tif") or
            mem.eql(u8, lower_ext, ".tiff");

        if (!is_convertible) continue;

        // Build output filename
        const basename_no_ext = entry.basename[0..ext_start];
        const output_name = try std.fmt.allocPrint(allocator, "{s}.png", .{basename_no_ext});
        defer allocator.free(output_name);

        // Build full output path (same directory as input)
        const dir_end = if (mem.lastIndexOfScalar(u8, entry.path, '/')) |idx| idx + 1 else 0;
        const output_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ entry.path[0..dir_end], output_name });
        defer allocator.free(output_path);

        // Check if output already exists
        if (dir.access(output_path, .{})) |_| {
            std.debug.print("Skipping {s} (output exists)\n", .{entry.path});
            skipped_count += 1;
            continue;
        } else |_| {}

        if (dry_run) {
            std.debug.print("Would convert: {s} -> {s}\n", .{ entry.path, output_path });
            converted_count += 1;
            continue;
        }

        std.debug.print("Converting: {s} -> {s}\n", .{ entry.path, output_path });

        // Use ffmpeg for conversion
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "ffmpeg",
                "-i",
                entry.path,
                "-y",
                output_path,
            },
            .cwd = null,
        }) catch |err| {
            std.debug.print("  Error running ffmpeg: {}\n", .{err});
            error_count += 1;
            continue;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        const convert_success = switch (result.term) {
            .Exited => |code| code == 0,
            else => false,
        };
        if (!convert_success) {
            std.debug.print("  ffmpeg failed\n", .{});
            error_count += 1;
            continue;
        }

        converted_count += 1;

        // Delete original if requested
        if (delete_original) {
            dir.deleteFile(entry.path) catch |err| {
                std.debug.print("  Error deleting original: {}\n", .{err});
            };
        }
    }

    std.debug.print("\n==============================\n", .{});
    std.debug.print("Summary:\n", .{});
    std.debug.print("==============================\n", .{});
    std.debug.print("Files converted: {d}\n", .{converted_count});
    if (skipped_count > 0) {
        std.debug.print("Files skipped: {d}\n", .{skipped_count});
    }
    if (error_count > 0) {
        std.debug.print("Errors: {d}\n", .{error_count});
    }
}

fn removeEmptyDirs(allocator: mem.Allocator, dry_run: bool) !void {
    std.debug.print("Removing empty directories...\n", .{});
    if (dry_run) {
        std.debug.print("DRY RUN MODE - No directories will be removed\n\n", .{});
    }

    var dir = try fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var removed_count: usize = 0;
    var error_count: usize = 0;

    var attempts: usize = 0;
    const max_attempts = 10;

    while (attempts < max_attempts) : (attempts += 1) {
        var found_empty = false;
        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (entry.kind != .directory) continue;

            var subdir = dir.openDir(entry.path, .{ .iterate = true }) catch continue;
            defer subdir.close();

            var iter = subdir.iterate();
            const first_entry = try iter.next();

            if (first_entry == null) {
                found_empty = true;
                if (dry_run) {
                    std.debug.print("Would remove: {s}\n", .{entry.path});
                    removed_count += 1;
                } else {
                    dir.deleteDir(entry.path) catch |err| {
                        std.debug.print("Error removing {s}: {}\n", .{ entry.path, err });
                        error_count += 1;
                        continue;
                    };
                    std.debug.print("Removed: {s}\n", .{entry.path});
                    removed_count += 1;
                }
            }
        }

        if (!found_empty) break;
    }

    std.debug.print("\nSummary:\n", .{});
    std.debug.print("Empty directories removed: {d}\n", .{removed_count});
    if (error_count > 0) {
        std.debug.print("Errors: {d}\n", .{error_count});
    }
}

// ============================================================================
// AI-Powered Image Sorting (Ollama Vision)
// ============================================================================

fn checkOllamaStatus(allocator: mem.Allocator) !bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl",
            "-s",
            "-f",
            "--max-time",
            "5",
            OLLAMA_URL ++ "/api/tags",
        },
        .max_output_bytes = 64 * 1024,
    }) catch {
        return false;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return switch (result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
}

fn imageToBase64(allocator: mem.Allocator, file_path: []const u8) ![]const u8 {
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    // Limit file size to 50MB for base64 encoding
    if (file_size > 50 * 1024 * 1024) {
        return error.FileTooLarge;
    }

    const file_data = try allocator.alloc(u8, file_size);
    defer allocator.free(file_data);

    const bytes_read = try file.preadAll(file_data, 0);
    if (bytes_read != file_size) {
        return error.IncompleteRead;
    }

    // Calculate base64 encoded size and allocate buffer
    const encoded_len = base64.Encoder.calcSize(file_size);
    const encoded = try allocator.alloc(u8, encoded_len);

    // Encode to base64
    _ = base64.Encoder.encode(encoded, file_data);

    return encoded;
}

fn escapeJsonString(allocator: mem.Allocator, input: []const u8) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);

    for (input) |c| {
        switch (c) {
            '"' => try result.appendSlice(allocator, "\\\""),
            '\\' => try result.appendSlice(allocator, "\\\\"),
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '\t' => try result.appendSlice(allocator, "\\t"),
            else => {
                if (c < 0x20) {
                    // Control characters - skip them
                    continue;
                }
                try result.append(allocator, c);
            },
        }
    }

    return result.toOwnedSlice(allocator);
}

fn callOllamaVision(allocator: mem.Allocator, image_base64: []const u8, prompt: []const u8, model: []const u8) ![]const u8 {
    // Build JSON request body
    const escaped_prompt = try escapeJsonString(allocator, prompt);
    defer allocator.free(escaped_prompt);

    const json_body = try std.fmt.allocPrint(allocator,
        \\{{"model":"{s}","prompt":"{s}","images":["{s}"],"stream":false}}
    , .{ model, escaped_prompt, image_base64 });
    defer allocator.free(json_body);

    // Write JSON to temp file (curl -d @file is more reliable for large payloads)
    const tmp_path = "/tmp/imtools_ollama_request.json";
    const tmp_file = try fs.cwd().createFile(tmp_path, .{});
    defer tmp_file.close();
    try tmp_file.writeAll(json_body);

    // Call Ollama API via curl
    const data_arg = "@" ++ tmp_path;
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl",
            "-s",
            "-X",
            "POST",
            "-H",
            "Content-Type: application/json",
            "-d",
            data_arg,
            "--max-time",
            "120",
            OLLAMA_URL ++ "/api/generate",
        },
        .max_output_bytes = 256 * 1024,
    }) catch |err| {
        std.debug.print("  Error calling Ollama: {}\n", .{err});
        return error.OllamaCallFailed;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const success = switch (result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
    if (!success) {
        return error.OllamaCallFailed;
    }

    // Parse response to extract "response" field
    // Looking for: "response":"..."
    const response_key = "\"response\":\"";
    const response_start = mem.indexOf(u8, result.stdout, response_key) orelse {
        return error.InvalidOllamaResponse;
    };
    const content_start = response_start + response_key.len;

    // Find the closing quote (handling escaped quotes)
    var content_end = content_start;
    var in_escape = false;
    while (content_end < result.stdout.len) : (content_end += 1) {
        const c = result.stdout[content_end];
        if (in_escape) {
            in_escape = false;
            continue;
        }
        if (c == '\\') {
            in_escape = true;
            continue;
        }
        if (c == '"') break;
    }

    const response_text = result.stdout[content_start..content_end];
    return try allocator.dupe(u8, response_text);
}

fn sanitizeCategoryName(allocator: mem.Allocator, name: []const u8) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);

    // First, unescape JSON escape sequences like \n
    var unescaped: std.ArrayListUnmanaged(u8) = .empty;
    defer unescaped.deinit(allocator);

    var i: usize = 0;
    while (i < name.len) : (i += 1) {
        if (name[i] == '\\' and i + 1 < name.len) {
            const next = name[i + 1];
            if (next == 'n' or next == 'r' or next == 't') {
                try unescaped.append(allocator, ' ');
                i += 1;
                continue;
            }
        }
        try unescaped.append(allocator, name[i]);
    }

    // Trim whitespace and newlines
    const trimmed = mem.trim(u8, unescaped.items, &std.ascii.whitespace);

    // Extract the first word only (category should be single word)
    var first_word_end: usize = 0;
    for (trimmed, 0..) |c, idx| {
        if (c == ' ' or c == '.' or c == ',' or c == '\n' or c == '\r') {
            break;
        }
        first_word_end = idx + 1;
    }
    const first_word = if (first_word_end > 0) trimmed[0..first_word_end] else trimmed;

    for (first_word) |c| {
        if (std.ascii.isAlphanumeric(c)) {
            try result.append(allocator, std.ascii.toLower(c));
        } else if (c == '-' or c == '_') {
            // Replace dashes with underscores, avoid duplicates
            if (result.items.len > 0 and result.items[result.items.len - 1] != '_') {
                try result.append(allocator, '_');
            }
        }
        // Skip other characters
    }

    // Remove trailing underscore
    while (result.items.len > 0 and result.items[result.items.len - 1] == '_') {
        _ = result.pop();
    }

    // Truncate to reasonable length
    const max_len: usize = 32;
    if (result.items.len > max_len) {
        result.shrinkRetainingCapacity(max_len);
    }

    // Default if empty
    if (result.items.len == 0) {
        try result.appendSlice(allocator, "misc");
    }

    return result.toOwnedSlice(allocator);
}

fn analyzeImageForCategory(allocator: mem.Allocator, image_path: []const u8, predefined_categories: ?[]const u8, model: []const u8) ![]const u8 {
    // Encode image to base64
    const image_base64 = try imageToBase64(allocator, image_path);
    defer allocator.free(image_base64);

    // Simple prompt that moondream responds well to
    const prompt = "Describe this image in one sentence.";

    // Retry with exponential backoff (3 attempts: 0ms, 1000ms, 3000ms)
    const max_retries: u32 = 3;
    var retry: u32 = 0;
    var last_err: anyerror = error.OllamaCallFailed;

    const response = while (retry < max_retries) : (retry += 1) {
        if (retry > 0) {
            // Exponential backoff: 1s, 3s
            const backoff_ms: u64 = @as(u64, 1000) * std.math.pow(u64, 2, retry - 1);
            const backoff_ns = backoff_ms * std.time.ns_per_ms;
            std.posix.nanosleep(backoff_ns / std.time.ns_per_s, @intCast(backoff_ns % std.time.ns_per_s));
        }

        break callOllamaVision(allocator, image_base64, prompt, model) catch |err| {
            last_err = err;
            continue;
        };
    } else {
        return last_err;
    };
    defer allocator.free(response);

    // If we have predefined categories, try to match the response to one of them
    if (predefined_categories) |cats| {
        // Split categories by comma and check if any appears in response
        var iter = mem.splitSequence(u8, cats, ",");
        while (iter.next()) |cat| {
            const trimmed_cat = mem.trim(u8, cat, &std.ascii.whitespace);
            // Case-insensitive search in response
            var lower_response: [512]u8 = undefined;
            const response_lower = std.ascii.lowerString(&lower_response, response[0..@min(response.len, 512)]);

            var lower_cat: [64]u8 = undefined;
            const cat_lower = std.ascii.lowerString(&lower_cat, trimmed_cat);

            if (mem.indexOf(u8, response_lower, cat_lower) != null) {
                return try allocator.dupe(u8, trimmed_cat);
            }
        }
        // No match found, return "uncategorized"
        return try allocator.dupe(u8, "uncategorized");
    }

    // For auto-categorization, extract key words from description
    return try extractCategoryFromDescription(allocator, response);
}

fn extractCategoryFromDescription(allocator: mem.Allocator, description: []const u8) ![]const u8 {
    // Keywords to category mapping - ordered by priority (first match wins)
    // SUBJECTS FIRST, then styles as absolute last resort
    // NO generic categories like "photo", "misc", "digital_art"
    const keywords = [_]struct { word: []const u8, category: []const u8 }{
        // === SPECIFIC SUBJECTS (highest priority) ===

        // Space/Cosmos - very specific
        .{ .word = "galaxy", .category = "space" },
        .{ .word = "nebula", .category = "space" },
        .{ .word = "planet", .category = "space" },
        .{ .word = "cosmos", .category = "space" },
        .{ .word = "astronaut", .category = "space" },
        .{ .word = "spaceship", .category = "space" },
        .{ .word = "asteroid", .category = "space" },
        .{ .word = "comet", .category = "space" },
        .{ .word = "satellite", .category = "space" },
        .{ .word = "orbit", .category = "space" },
        .{ .word = "solar", .category = "space" },
        .{ .word = "lunar", .category = "space" },
        .{ .word = "milky way", .category = "space" },
        .{ .word = "universe", .category = "space" },
        .{ .word = "celestial", .category = "space" },
        .{ .word = "constellation", .category = "space" },
        .{ .word = "aurora", .category = "space" },
        .{ .word = "northern lights", .category = "space" },

        // Anime/Manga - specific style
        .{ .word = "anime", .category = "anime" },
        .{ .word = "manga", .category = "anime" },
        .{ .word = "waifu", .category = "anime" },
        .{ .word = "chibi", .category = "anime" },
        .{ .word = "kawaii", .category = "anime" },
        .{ .word = "otaku", .category = "anime" },
        .{ .word = "japanese animation", .category = "anime" },

        // Fantasy creatures/themes
        .{ .word = "dragon", .category = "fantasy" },
        .{ .word = "wizard", .category = "fantasy" },
        .{ .word = "witch", .category = "fantasy" },
        .{ .word = "elf", .category = "fantasy" },
        .{ .word = "dwarf", .category = "fantasy" },
        .{ .word = "fairy", .category = "fantasy" },
        .{ .word = "unicorn", .category = "fantasy" },
        .{ .word = "phoenix", .category = "fantasy" },
        .{ .word = "griffin", .category = "fantasy" },
        .{ .word = "centaur", .category = "fantasy" },
        .{ .word = "mermaid", .category = "fantasy" },
        .{ .word = "demon", .category = "fantasy" },
        .{ .word = "angel", .category = "fantasy" },
        .{ .word = "knight", .category = "fantasy" },
        .{ .word = "castle", .category = "fantasy" },
        .{ .word = "medieval", .category = "fantasy" },
        .{ .word = "mythical", .category = "fantasy" },
        .{ .word = "magical", .category = "fantasy" },
        .{ .word = "enchanted", .category = "fantasy" },
        .{ .word = "sorcerer", .category = "fantasy" },
        .{ .word = "spell", .category = "fantasy" },
        .{ .word = "potion", .category = "fantasy" },

        // Cyberpunk/Sci-fi
        .{ .word = "cyberpunk", .category = "cyberpunk" },
        .{ .word = "neon lights", .category = "cyberpunk" },
        .{ .word = "hologram", .category = "cyberpunk" },
        .{ .word = "dystopia", .category = "cyberpunk" },
        .{ .word = "android", .category = "scifi" },
        .{ .word = "cyborg", .category = "scifi" },
        .{ .word = "robot", .category = "scifi" },
        .{ .word = "mech", .category = "scifi" },
        .{ .word = "futuristic", .category = "scifi" },
        .{ .word = "sci-fi", .category = "scifi" },
        .{ .word = "alien", .category = "scifi" },
        .{ .word = "laser", .category = "scifi" },

        // Animals - specific types
        .{ .word = "wolf", .category = "animals" },
        .{ .word = "fox", .category = "animals" },
        .{ .word = "lion", .category = "animals" },
        .{ .word = "tiger", .category = "animals" },
        .{ .word = "bear", .category = "animals" },
        .{ .word = "eagle", .category = "animals" },
        .{ .word = "owl", .category = "animals" },
        .{ .word = "deer", .category = "animals" },
        .{ .word = "horse", .category = "animals" },
        .{ .word = "elephant", .category = "animals" },
        .{ .word = "whale", .category = "animals" },
        .{ .word = "dolphin", .category = "animals" },
        .{ .word = "shark", .category = "animals" },
        .{ .word = "snake", .category = "animals" },
        .{ .word = "butterfly", .category = "animals" },
        .{ .word = "cat", .category = "animals" },
        .{ .word = "dog", .category = "animals" },
        .{ .word = "bird", .category = "animals" },
        .{ .word = "fish", .category = "animals" },
        .{ .word = "wildlife", .category = "animals" },
        .{ .word = "animal", .category = "animals" },

        // Nature - specific elements
        .{ .word = "mountain", .category = "mountains" },
        .{ .word = "mountains", .category = "mountains" },
        .{ .word = "peak", .category = "mountains" },
        .{ .word = "cliff", .category = "mountains" },
        .{ .word = "canyon", .category = "mountains" },
        .{ .word = "volcano", .category = "mountains" },

        .{ .word = "forest", .category = "forest" },
        .{ .word = "woods", .category = "forest" },
        .{ .word = "jungle", .category = "forest" },
        .{ .word = "rainforest", .category = "forest" },
        .{ .word = "trees", .category = "forest" },
        .{ .word = "tree", .category = "forest" },

        .{ .word = "ocean", .category = "ocean" },
        .{ .word = "sea", .category = "ocean" },
        .{ .word = "waves", .category = "ocean" },
        .{ .word = "underwater", .category = "ocean" },
        .{ .word = "coral", .category = "ocean" },
        .{ .word = "beach", .category = "beach" },
        .{ .word = "coast", .category = "beach" },
        .{ .word = "shore", .category = "beach" },
        .{ .word = "tropical", .category = "beach" },
        .{ .word = "island", .category = "beach" },

        .{ .word = "lake", .category = "lake" },
        .{ .word = "pond", .category = "lake" },
        .{ .word = "river", .category = "river" },
        .{ .word = "stream", .category = "river" },
        .{ .word = "waterfall", .category = "waterfall" },
        .{ .word = "cascade", .category = "waterfall" },

        .{ .word = "sunset", .category = "sunset" },
        .{ .word = "sunrise", .category = "sunrise" },
        .{ .word = "dawn", .category = "sunrise" },
        .{ .word = "dusk", .category = "sunset" },
        .{ .word = "golden hour", .category = "sunset" },

        .{ .word = "flower", .category = "flowers" },
        .{ .word = "flowers", .category = "flowers" },
        .{ .word = "bloom", .category = "flowers" },
        .{ .word = "blossom", .category = "flowers" },
        .{ .word = "rose", .category = "flowers" },
        .{ .word = "garden", .category = "flowers" },

        .{ .word = "snow", .category = "winter" },
        .{ .word = "ice", .category = "winter" },
        .{ .word = "frozen", .category = "winter" },
        .{ .word = "glacier", .category = "winter" },
        .{ .word = "winter", .category = "winter" },
        .{ .word = "blizzard", .category = "winter" },

        .{ .word = "desert", .category = "desert" },
        .{ .word = "dune", .category = "desert" },
        .{ .word = "sand", .category = "desert" },
        .{ .word = "oasis", .category = "desert" },

        // City/Urban
        .{ .word = "skyline", .category = "city" },
        .{ .word = "skyscraper", .category = "city" },
        .{ .word = "downtown", .category = "city" },
        .{ .word = "metropolis", .category = "city" },
        .{ .word = "cityscape", .category = "city" },
        .{ .word = "urban", .category = "city" },
        .{ .word = "city", .category = "city" },
        .{ .word = "buildings", .category = "city" },
        .{ .word = "building", .category = "city" },
        .{ .word = "tower", .category = "city" },
        .{ .word = "street", .category = "street" },
        .{ .word = "alley", .category = "street" },
        .{ .word = "road", .category = "street" },

        // Architecture
        .{ .word = "cathedral", .category = "architecture" },
        .{ .word = "church", .category = "architecture" },
        .{ .word = "temple", .category = "architecture" },
        .{ .word = "palace", .category = "architecture" },
        .{ .word = "bridge", .category = "architecture" },
        .{ .word = "monument", .category = "architecture" },
        .{ .word = "architecture", .category = "architecture" },

        // Vehicles
        .{ .word = "car", .category = "vehicles" },
        .{ .word = "motorcycle", .category = "vehicles" },
        .{ .word = "plane", .category = "vehicles" },
        .{ .word = "airplane", .category = "vehicles" },
        .{ .word = "helicopter", .category = "vehicles" },
        .{ .word = "ship", .category = "vehicles" },
        .{ .word = "boat", .category = "vehicles" },
        .{ .word = "train", .category = "vehicles" },
        .{ .word = "bike", .category = "vehicles" },
        .{ .word = "truck", .category = "vehicles" },

        // Horror
        .{ .word = "skull", .category = "horror" },
        .{ .word = "skeleton", .category = "horror" },
        .{ .word = "zombie", .category = "horror" },
        .{ .word = "vampire", .category = "horror" },
        .{ .word = "ghost", .category = "horror" },
        .{ .word = "haunted", .category = "horror" },
        .{ .word = "creepy", .category = "horror" },
        .{ .word = "horror", .category = "horror" },
        .{ .word = "scary", .category = "horror" },

        // Gaming
        .{ .word = "gaming", .category = "gaming" },
        .{ .word = "game", .category = "gaming" },
        .{ .word = "video game", .category = "gaming" },
        .{ .word = "controller", .category = "gaming" },
        .{ .word = "console", .category = "gaming" },

        // Technology
        .{ .word = "circuit", .category = "tech" },
        .{ .word = "computer", .category = "tech" },
        .{ .word = "programming", .category = "tech" },
        .{ .word = "code", .category = "tech" },
        .{ .word = "hacker", .category = "tech" },
        .{ .word = "matrix", .category = "tech" },
        .{ .word = "binary", .category = "tech" },
        .{ .word = "data", .category = "tech" },
        .{ .word = "network", .category = "tech" },

        // Music
        .{ .word = "guitar", .category = "music" },
        .{ .word = "piano", .category = "music" },
        .{ .word = "violin", .category = "music" },
        .{ .word = "drums", .category = "music" },
        .{ .word = "music", .category = "music" },
        .{ .word = "concert", .category = "music" },

        // Food
        .{ .word = "food", .category = "food" },
        .{ .word = "fruit", .category = "food" },
        .{ .word = "coffee", .category = "food" },
        .{ .word = "cake", .category = "food" },
        .{ .word = "sushi", .category = "food" },

        // Abstract patterns
        .{ .word = "fractal", .category = "abstract" },
        .{ .word = "geometric", .category = "abstract" },
        .{ .word = "spiral", .category = "abstract" },
        .{ .word = "kaleidoscope", .category = "abstract" },
        .{ .word = "abstract", .category = "abstract" },
        .{ .word = "pattern", .category = "abstract" },

        // === MOOD/ATMOSPHERE (secondary priority) ===

        .{ .word = "night", .category = "night" },
        .{ .word = "nighttime", .category = "night" },
        .{ .word = "midnight", .category = "night" },
        .{ .word = "starry", .category = "night" },
        .{ .word = "moonlit", .category = "night" },
        .{ .word = "stars", .category = "night" },
        .{ .word = "moon", .category = "night" },

        .{ .word = "neon", .category = "neon" },
        .{ .word = "glowing", .category = "neon" },
        .{ .word = "luminous", .category = "neon" },

        .{ .word = "minimalist", .category = "minimalist" },
        .{ .word = "minimal", .category = "minimalist" },
        .{ .word = "simple", .category = "minimalist" },
        .{ .word = "clean", .category = "minimalist" },

        .{ .word = "dark", .category = "dark" },
        .{ .word = "moody", .category = "dark" },
        .{ .word = "gloomy", .category = "dark" },
        .{ .word = "shadow", .category = "dark" },

        .{ .word = "colorful", .category = "colorful" },
        .{ .word = "rainbow", .category = "colorful" },
        .{ .word = "vibrant", .category = "colorful" },

        .{ .word = "retro", .category = "retro" },
        .{ .word = "vintage", .category = "retro" },
        .{ .word = "nostalgic", .category = "retro" },

        // === PEOPLE (last among subjects) ===
        .{ .word = "woman", .category = "portrait" },
        .{ .word = "man", .category = "portrait" },
        .{ .word = "girl", .category = "portrait" },
        .{ .word = "boy", .category = "portrait" },
        .{ .word = "person", .category = "portrait" },
        .{ .word = "people", .category = "portrait" },
        .{ .word = "face", .category = "portrait" },
        .{ .word = "portrait", .category = "portrait" },
        .{ .word = "character", .category = "portrait" },

        // === NATURE GENERIC (fallback for nature images) ===
        .{ .word = "nature", .category = "nature" },
        .{ .word = "landscape", .category = "landscape" },
        .{ .word = "scenery", .category = "landscape" },
        .{ .word = "outdoor", .category = "landscape" },
        .{ .word = "sky", .category = "sky" },
        .{ .word = "clouds", .category = "sky" },
        .{ .word = "cloud", .category = "sky" },
        .{ .word = "horizon", .category = "landscape" },
        .{ .word = "water", .category = "water" },

        // === GENERIC SUBJECTS (catch-all before colors) ===
        .{ .word = "view", .category = "landscape" },
        .{ .word = "scene", .category = "landscape" },
        .{ .word = "background", .category = "landscape" },
        .{ .word = "image", .category = "landscape" },  // often "image of a..."
        .{ .word = "picture", .category = "landscape" },

        // Common descriptions moondream uses
        .{ .word = "standing", .category = "portrait" },
        .{ .word = "sitting", .category = "portrait" },
        .{ .word = "looking", .category = "portrait" },
        .{ .word = "wearing", .category = "portrait" },
        .{ .word = "holding", .category = "portrait" },

        // === COLORS (last resort before uncategorized) ===
        .{ .word = "blue", .category = "blue" },
        .{ .word = "red", .category = "red" },
        .{ .word = "green", .category = "green" },
        .{ .word = "purple", .category = "purple" },
        .{ .word = "orange", .category = "orange" },
        .{ .word = "pink", .category = "pink" },
        .{ .word = "yellow", .category = "yellow" },
        .{ .word = "black", .category = "dark" },
        .{ .word = "white", .category = "white" },
        .{ .word = "grey", .category = "dark" },
        .{ .word = "gray", .category = "dark" },
        .{ .word = "brown", .category = "nature" },
        .{ .word = "golden", .category = "sunset" },
        .{ .word = "silver", .category = "minimalist" },
    };

    // Convert description to lowercase for matching
    var lower_desc: [1024]u8 = undefined;
    const desc_len = @min(description.len, 1024);
    const desc_lower = std.ascii.lowerString(lower_desc[0..desc_len], description[0..desc_len]);

    // Check each keyword
    for (keywords) |kw| {
        if (mem.indexOf(u8, desc_lower, kw.word) != null) {
            return try allocator.dupe(u8, kw.category);
        }
    }

    // No match found, fall back to "uncategorized"
    return try allocator.dupe(u8, "uncategorized");
}

const ImageResult = struct {
    path: []const u8,
    category: ?[]const u8,
    err: bool,
};

fn sortImages(allocator: mem.Allocator, config: SortConfig) !void {
    std.debug.print("AI-powered image sorting using Ollama ({s})...\n", .{config.model});
    std.debug.print("Workers: {d}\n", .{config.workers});
    if (config.dry_run) {
        std.debug.print("DRY RUN MODE - No files will be moved\n", .{});
    }
    std.debug.print("\n", .{});

    // Check Ollama availability
    std.debug.print("Checking Ollama status...\n", .{});
    const ollama_available = try checkOllamaStatus(allocator);
    if (!ollama_available) {
        std.debug.print(
            \\
            \\Error: Ollama is not available at {s}
            \\
            \\To fix this:
            \\  1. Install Ollama: curl -fsSL https://ollama.ai/install.sh | sh
            \\  2. Start Ollama: ollama serve
            \\  3. Pull a vision model: ollama pull {s}
            \\
        , .{ OLLAMA_URL, config.model });
        return error.OllamaNotAvailable;
    }
    std.debug.print("Ollama is running\n\n", .{});

    // Open directory
    var dir = try fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    // Determine output directory
    var output_dir: fs.Dir = undefined;
    const use_separate_output = !mem.eql(u8, config.output_dir, ".");

    if (use_separate_output) {
        fs.cwd().makeDir(config.output_dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                std.debug.print("Error creating output directory: {}\n", .{err});
                return err;
            }
        };
        output_dir = try fs.cwd().openDir(config.output_dir, .{});
    } else {
        output_dir = try fs.cwd().openDir(".", .{});
    }
    defer output_dir.close();

    var sorted_count: usize = 0;
    var error_count: usize = 0;
    var categories_created = std.StringHashMap(void).init(allocator);
    defer {
        var it = categories_created.keyIterator();
        while (it.next()) |key| {
            allocator.free(key.*);
        }
        categories_created.deinit();
    }

    // Collect images to process
    var images_to_process: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (images_to_process.items) |path| {
            allocator.free(path);
        }
        images_to_process.deinit(allocator);
    }

    if (config.recursive) {
        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!ImageType.isImage(entry.basename)) continue;
            // Skip files already in category subdirectories if outputting to same dir
            if (!use_separate_output and mem.indexOfScalar(u8, entry.path, '/') != null) continue;

            const path_copy = try allocator.dupe(u8, entry.path);
            try images_to_process.append(allocator, path_copy);
        }
    } else {
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!ImageType.isImage(entry.name)) continue;

            const path_copy = try allocator.dupe(u8, entry.name);
            try images_to_process.append(allocator, path_copy);
        }
    }

    std.debug.print("Found {d} image(s) to process\n\n", .{images_to_process.items.len});

    // Process images in parallel batches
    const batch_size = config.workers;
    const total_images = images_to_process.items.len;
    var processed: usize = 0;

    while (processed < total_images) {
        const batch_end = @min(processed + batch_size, total_images);
        const current_batch = images_to_process.items[processed..batch_end];

        // Analyze batch in parallel using threads
        var results: [16]ImageResult = undefined; // Max 16 workers
        var threads: [16]?std.Thread = [_]?std.Thread{null} ** 16;

        const WorkerContext = struct {
            image_path: []const u8,
            categories: ?[]const u8,
            model: []const u8,
            result: *ImageResult,
            alloc: mem.Allocator,
        };

        for (current_batch, 0..) |image_path, batch_idx| {
            results[batch_idx] = ImageResult{
                .path = image_path,
                .category = null,
                .err = false,
            };

            // Create a thread-local context
            const ctx = WorkerContext{
                .image_path = image_path,
                .categories = config.categories,
                .model = config.model,
                .result = &results[batch_idx],
                .alloc = allocator,
            };

            threads[batch_idx] = std.Thread.spawn(.{}, struct {
                fn work(context: WorkerContext) void {
                    const cat = analyzeImageForCategory(context.alloc, context.image_path, context.categories, context.model) catch {
                        context.result.err = true;
                        return;
                    };
                    context.result.category = cat;
                }
            }.work, .{ctx}) catch blk: {
                // Fallback to sequential if thread spawn fails
                const cat = analyzeImageForCategory(allocator, image_path, config.categories, config.model) catch {
                    results[batch_idx].err = true;
                    break :blk null;
                };
                results[batch_idx].category = cat;
                break :blk null;
            };
        }

        // Wait for all threads in batch to complete
        for (threads[0..current_batch.len]) |maybe_thread| {
            if (maybe_thread) |thread| {
                thread.join();
            }
        }

        // Process results from batch
        for (results[0..current_batch.len], 0..) |result, batch_idx| {
            const idx = processed + batch_idx;
            std.debug.print("[{d}/{d}] {s}\n", .{ idx + 1, total_images, result.path });

            if (result.err or result.category == null) {
                std.debug.print("  Error analyzing image\n", .{});
                error_count += 1;
                continue;
            }

            const category = result.category.?;
            defer allocator.free(category);
            std.debug.print("  Category: {s}\n", .{category});

            // Create category directory if needed
            if (!categories_created.contains(category)) {
                if (!config.dry_run) {
                    output_dir.makeDir(category) catch |err| {
                        if (err != error.PathAlreadyExists) {
                            std.debug.print("  Error creating category dir: {}\n", .{err});
                            error_count += 1;
                            continue;
                        }
                    };
                }
                const cat_copy = allocator.dupe(u8, category) catch {
                    continue;
                };
                categories_created.put(cat_copy, {}) catch {};
            }

            // Build destination path
            const basename = fs.path.basename(result.path);
            const dest_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ category, basename }) catch {
                continue;
            };
            defer allocator.free(dest_path);

            if (config.dry_run) {
                if (use_separate_output) {
                    std.debug.print("  Would move to: {s}/{s}\n", .{ config.output_dir, dest_path });
                } else {
                    std.debug.print("  Would move to: {s}\n", .{dest_path});
                }
                sorted_count += 1;
            } else {
                // Move file to category folder
                var move_success = false;
                if (use_separate_output) {
                    // Copy to output dir then delete original
                    const src_file = dir.openFile(result.path, .{}) catch |err| {
                        std.debug.print("  Error opening file: {}\n", .{err});
                        error_count += 1;
                        continue;
                    };
                    defer src_file.close();

                    const dest_file = output_dir.createFile(dest_path, .{}) catch |err| {
                        std.debug.print("  Error creating dest: {}\n", .{err});
                        error_count += 1;
                        continue;
                    };
                    defer dest_file.close();

                    const stat = src_file.stat() catch {
                        error_count += 1;
                        continue;
                    };
                    var remaining = stat.size;
                    var buf: [8192]u8 = undefined;
                    var copy_failed = false;
                    while (remaining > 0) {
                        const bytes_read = src_file.read(&buf) catch {
                            copy_failed = true;
                            break;
                        };
                        if (bytes_read == 0) break;
                        dest_file.writeAll(buf[0..bytes_read]) catch {
                            copy_failed = true;
                            break;
                        };
                        remaining -= bytes_read;
                    }

                    if (copy_failed) {
                        error_count += 1;
                        continue;
                    }

                    // Delete original
                    dir.deleteFile(result.path) catch |err| {
                        std.debug.print("  Warning: could not delete original: {}\n", .{err});
                    };
                    move_success = true;
                } else {
                    // Move within same filesystem
                    dir.rename(result.path, dest_path) catch |err| {
                        std.debug.print("  Error moving file: {}\n", .{err});
                        error_count += 1;
                        continue;
                    };
                    move_success = true;
                }
                if (move_success) {
                    std.debug.print("  Moved to: {s}\n", .{dest_path});
                    sorted_count += 1;
                }
            }
        }

        processed = batch_end;

        // Cooldown between batches
        if (processed < total_images and config.cooldown_ms > 0) {
            std.posix.nanosleep(config.cooldown_ms / 1000, (config.cooldown_ms % 1000) * 1_000_000);
        }
    }

    std.debug.print("\n==============================\n", .{});
    std.debug.print("Summary:\n", .{});
    std.debug.print("==============================\n", .{});
    std.debug.print("Images sorted: {d}\n", .{sorted_count});
    std.debug.print("Categories created: {d}\n", .{categories_created.count()});
    if (error_count > 0) {
        std.debug.print("Errors: {d}\n", .{error_count});
    }
    if (config.dry_run and sorted_count > 0) {
        std.debug.print("\nThis was a dry run. Run without --dry-run to actually move files.\n", .{});
    }
}

fn downloadWallpapers(allocator: mem.Allocator, query: []const u8, limit: usize, output_dir: []const u8) !void {
    std.debug.print("Downloading wallpapers from wallhaven.cc...\n", .{});
    std.debug.print("Query: {s}\n", .{query});
    std.debug.print("Limit: {d}\n", .{limit});

    // Check if we're already in the target directory or should use current dir
    var actual_output_dir = output_dir;

    // Get current working directory
    var cwd_buf: [fs.max_path_bytes]u8 = undefined;
    const cwd = fs.cwd().realpath(".", &cwd_buf) catch output_dir;

    // If cwd ends with the output_dir name (e.g., we're in "wallpapers" and output is "wallpapers")
    // or if output_dir is "." or current dir already matches, use current directory
    if (mem.eql(u8, output_dir, ".")) {
        actual_output_dir = ".";
    } else if (mem.endsWith(u8, cwd, output_dir)) {
        std.debug.print("Already in target directory, saving to current directory\n", .{});
        actual_output_dir = ".";
    } else {
        // Create output directory if needed
        fs.cwd().makeDir(output_dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                std.debug.print("Error creating output directory: {}\n", .{err});
                return err;
            }
        };
    }

    std.debug.print("Output: {s}\n\n", .{if (mem.eql(u8, actual_output_dir, ".")) cwd else actual_output_dir});

    // URL encode the query
    var encoded_query: std.ArrayListUnmanaged(u8) = .empty;
    defer encoded_query.deinit(allocator);
    const hex_chars = "0123456789ABCDEF";
    for (query) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
            try encoded_query.append(allocator, c);
        } else if (c == ' ') {
            try encoded_query.append(allocator, '+');
        } else {
            try encoded_query.append(allocator, '%');
            try encoded_query.append(allocator, hex_chars[c >> 4]);
            try encoded_query.append(allocator, hex_chars[c & 0x0F]);
        }
    }

    // Build search URL
    const search_url = try std.fmt.allocPrint(allocator, "https://wallhaven.cc/search?q={s}", .{encoded_query.items});
    defer allocator.free(search_url);

    std.debug.print("Fetching search results...\n", .{});

    // Fetch search page using curl
    const curl_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl",
            "-s",
            "-L",
            "-A",
            "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0",
            search_url,
        },
        .max_output_bytes = 1024 * 1024,
    }) catch |err| {
        std.debug.print("Error running curl: {}\n", .{err});
        return err;
    };
    defer allocator.free(curl_result.stdout);
    defer allocator.free(curl_result.stderr);

    const curl_success = switch (curl_result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
    if (!curl_success) {
        std.debug.print("curl failed\n", .{});
        return error.CurlFailed;
    }

    // Parse wallpaper IDs from HTML (look for data-wallpaper-id="...")
    var ids: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (ids.items) |id| allocator.free(id);
        ids.deinit(allocator);
    }

    const html = curl_result.stdout;
    var pos: usize = 0;
    while (pos < html.len and ids.items.len < limit) {
        const pattern = "data-wallpaper-id=\"";
        const start = mem.indexOfPos(u8, html, pos, pattern) orelse break;
        const id_start = start + pattern.len;
        const id_end = mem.indexOfPos(u8, html, id_start, "\"") orelse break;
        const id = html[id_start..id_end];

        // Check for duplicates
        var is_dup = false;
        for (ids.items) |existing| {
            if (mem.eql(u8, existing, id)) {
                is_dup = true;
                break;
            }
        }

        if (!is_dup) {
            const id_copy = try allocator.dupe(u8, id);
            try ids.append(allocator, id_copy);
        }

        pos = id_end;
    }

    if (ids.items.len == 0) {
        std.debug.print("No wallpapers found for query: {s}\n", .{query});
        return;
    }

    std.debug.print("Found {d} wallpaper(s)\n\n", .{ids.items.len});

    var downloaded_count: usize = 0;
    var converted_count: usize = 0;
    var error_count: usize = 0;

    // Download each wallpaper
    for (ids.items) |id| {
        const folder = id[0..2];

        // Try JPG first
        const jpg_url = try std.fmt.allocPrint(allocator, "https://w.wallhaven.cc/full/{s}/wallhaven-{s}.jpg", .{ folder, id });
        defer allocator.free(jpg_url);

        const jpg_path = try std.fmt.allocPrint(allocator, "{s}/wallhaven-{s}.jpg", .{ actual_output_dir, id });
        defer allocator.free(jpg_path);

        const png_path = try std.fmt.allocPrint(allocator, "{s}/wallhaven-{s}.png", .{ actual_output_dir, id });
        defer allocator.free(png_path);

        // Check if PNG already exists
        if (fs.cwd().access(png_path, .{})) |_| {
            std.debug.print("Skipping {s} (already exists)\n", .{id});
            continue;
        } else |_| {}

        std.debug.print("Downloading {s}...\n", .{id});

        // Try downloading JPG
        var is_jpg = true;
        var download_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "curl",
                "-s",
                "-L",
                "-f",
                "-A",
                "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0",
                "-o",
                jpg_path,
                jpg_url,
            },
        }) catch |err| {
            std.debug.print("  Error running curl for {s}: {}\n", .{ id, err });
            error_count += 1;
            continue;
        };
        allocator.free(download_result.stdout);
        allocator.free(download_result.stderr);

        // If JPG failed (404), try PNG
        const jpg_success = switch (download_result.term) {
            .Exited => |code| code == 0,
            else => false,
        };
        if (!jpg_success) {
            is_jpg = false;
            const png_url = try std.fmt.allocPrint(allocator, "https://w.wallhaven.cc/full/{s}/wallhaven-{s}.png", .{ folder, id });
            defer allocator.free(png_url);

            download_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{
                    "curl",
                    "-s",
                    "-L",
                    "-f",
                    "-A",
                    "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0",
                    "-o",
                    png_path,
                    png_url,
                },
            }) catch |err| {
                std.debug.print("  Error running curl for {s}: {}\n", .{ id, err });
                error_count += 1;
                continue;
            };
            allocator.free(download_result.stdout);
            allocator.free(download_result.stderr);

            const png_success = switch (download_result.term) {
                .Exited => |code| code == 0,
                else => false,
            };
            if (!png_success) {
                std.debug.print("  Failed to download {s} (neither JPG nor PNG found)\n", .{id});
                error_count += 1;
                continue;
            }

            std.debug.print("  Downloaded: {s}\n", .{png_path});
            downloaded_count += 1;
            continue;
        }

        downloaded_count += 1;

        // Convert JPG to PNG if needed
        if (is_jpg) {
            std.debug.print("  Converting to PNG...\n", .{});

            const ffmpeg_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{
                    "ffmpeg",
                    "-i",
                    jpg_path,
                    "-y",
                    png_path,
                },
            }) catch |err| {
                std.debug.print("  Error running ffmpeg: {}\n", .{err});
                continue;
            };
            defer allocator.free(ffmpeg_result.stdout);
            defer allocator.free(ffmpeg_result.stderr);

            const ffmpeg_success = switch (ffmpeg_result.term) {
                .Exited => |code| code == 0,
                else => false,
            };
            if (!ffmpeg_success) {
                std.debug.print("  ffmpeg conversion failed\n", .{});
                continue;
            }

            // Delete original JPG
            fs.cwd().deleteFile(jpg_path) catch |err| {
                std.debug.print("  Error deleting JPG: {}\n", .{err});
            };

            converted_count += 1;
            std.debug.print("  Converted: {s}\n", .{png_path});
        }
    }

    std.debug.print("\n==============================\n", .{});
    std.debug.print("Summary:\n", .{});
    std.debug.print("==============================\n", .{});
    std.debug.print("Downloaded: {d}\n", .{downloaded_count});
    std.debug.print("Converted to PNG: {d}\n", .{converted_count});
    if (error_count > 0) {
        std.debug.print("Errors: {d}\n", .{error_count});
    }
}

fn printUsage() void {
    std.debug.print(
        \\imtools - Image manipulation utilities
        \\
        \\Usage:
        \\  imtools <command> [options]
        \\
        \\Commands:
        \\  flatten              Move all images from subdirectories to current directory
        \\  find-duplicates      Find duplicate images by SHA256 hash
        \\  delete-portrait      Delete portrait orientation images (height > width)
        \\  remove-empty-dirs    Remove empty directories
        \\  convert-to-png       Convert all images to PNG format (requires ffmpeg)
        \\  download             Download wallpapers from wallhaven.cc (requires curl, ffmpeg)
        \\  sort                 AI-powered image categorization using Ollama vision (requires curl, ollama)
        \\  help                 Show this help message
        \\
        \\Options:
        \\  --dry-run            Show what would be done without making changes
        \\  --delete             Enable deletion mode (for find-duplicates, convert-to-png)
        \\  --query <string>     Search query for download command
        \\  --limit <number>     Number of wallpapers to download (default: 10)
        \\  --output <dir>       Output directory for download/sort (default: wallpapers/current dir)
        \\  --categories <list>  Predefined categories for sort (comma-separated)
        \\  --cooldown <ms>      Delay between batches in ms (default: 500)
        \\  --model <name>       Ollama vision model (default: moondream:1.8b)
        \\  --workers <n>        Parallel workers for sort (default: 4, max: 16)
        \\  --recursive          Process subdirectories (default for sort)
        \\  --no-recursive       Only process current directory
        \\
        \\Examples:
        \\  imtools flatten
        \\  imtools flatten --dry-run
        \\  imtools find-duplicates
        \\  imtools find-duplicates --delete
        \\  imtools delete-portrait --dry-run
        \\  imtools remove-empty-dirs
        \\  imtools convert-to-png
        \\  imtools convert-to-png --delete   # delete originals after conversion
        \\  imtools download --query "nature" --limit 20
        \\  imtools download --query "mountains" --output ./my-wallpapers
        \\  imtools sort --dry-run
        \\  imtools sort --categories "nature,anime,abstract,city,space"
        \\  imtools sort --output ./sorted --cooldown 3000
        \\  imtools sort --model llama3.2-vision:latest
        \\
    , .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];
    var dry_run = false;
    var delete_mode = false;
    var query: ?[]const u8 = null;
    var limit: usize = 10;
    var output_dir: []const u8 = "wallpapers";
    var categories: ?[]const u8 = null;
    var cooldown_ms: u64 = 2000;
    var recursive = true;
    var model: []const u8 = DEFAULT_VISION_MODEL;
    var workers: u32 = 4;

    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (mem.eql(u8, arg, "--dry-run")) {
            dry_run = true;
        } else if (mem.eql(u8, arg, "--delete")) {
            delete_mode = true;
        } else if (mem.eql(u8, arg, "--query")) {
            if (i + 1 < args.len) {
                i += 1;
                query = args[i];
            }
        } else if (mem.eql(u8, arg, "--limit")) {
            if (i + 1 < args.len) {
                i += 1;
                limit = std.fmt.parseInt(usize, args[i], 10) catch 10;
            }
        } else if (mem.eql(u8, arg, "--output")) {
            if (i + 1 < args.len) {
                i += 1;
                output_dir = args[i];
            }
        } else if (mem.eql(u8, arg, "--categories")) {
            if (i + 1 < args.len) {
                i += 1;
                categories = args[i];
            }
        } else if (mem.eql(u8, arg, "--cooldown")) {
            if (i + 1 < args.len) {
                i += 1;
                cooldown_ms = std.fmt.parseInt(u64, args[i], 10) catch 500;
            }
        } else if (mem.eql(u8, arg, "--model")) {
            if (i + 1 < args.len) {
                i += 1;
                model = args[i];
            }
        } else if (mem.eql(u8, arg, "--workers")) {
            if (i + 1 < args.len) {
                i += 1;
                workers = std.fmt.parseInt(u32, args[i], 10) catch 4;
                if (workers > 16) workers = 16; // Max 16 workers
                if (workers == 0) workers = 1;
            }
        } else if (mem.eql(u8, arg, "--recursive")) {
            recursive = true;
        } else if (mem.eql(u8, arg, "--no-recursive")) {
            recursive = false;
        }
    }

    if (mem.eql(u8, command, "flatten")) {
        try flattenImages(allocator, dry_run);
    } else if (mem.eql(u8, command, "find-duplicates")) {
        try findDuplicates(allocator, delete_mode);
    } else if (mem.eql(u8, command, "delete-portrait")) {
        try deletePortraitImages(allocator, dry_run);
    } else if (mem.eql(u8, command, "remove-empty-dirs")) {
        try removeEmptyDirs(allocator, dry_run);
    } else if (mem.eql(u8, command, "convert-to-png")) {
        try convertToPng(allocator, dry_run, delete_mode);
    } else if (mem.eql(u8, command, "download")) {
        if (query == null) {
            std.debug.print("Error: --query is required for download command\n\n", .{});
            printUsage();
            std.process.exit(1);
        }
        try downloadWallpapers(allocator, query.?, limit, output_dir);
    } else if (mem.eql(u8, command, "sort")) {
        sortImages(allocator, .{
            .dry_run = dry_run,
            .recursive = recursive,
            .categories = categories,
            .output_dir = if (mem.eql(u8, output_dir, "wallpapers")) "." else output_dir,
            .cooldown_ms = cooldown_ms,
            .model = model,
            .workers = workers,
        }) catch |err| {
            if (err == error.OllamaNotAvailable) {
                std.process.exit(1);
            }
            return err;
        };
    } else if (mem.eql(u8, command, "help")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n\n", .{command});
        printUsage();
        std.process.exit(1);
    }
}
