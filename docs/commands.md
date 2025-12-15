# Command Reference

Complete reference for all imtools commands with examples.

## Table of Contents

- [Overview](#overview)
- [Global Options](#global-options)
- [Commands](#commands)
  - [flatten](#flatten)
  - [find-duplicates](#find-duplicates)
  - [delete-portrait](#delete-portrait)
  - [remove-empty-dirs](#remove-empty-dirs)
  - [convert-to-png](#convert-to-png)
  - [download](#download)
  - [sort](#sort)
  - [help](#help)
- [Exit Codes](#exit-codes)
- [Common Workflows](#common-workflows)

---

## Overview

```
imtools <command> [options]
```

All commands operate on the **current working directory** by default. Always `cd` into your image folder before running commands.

---

## Global Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview changes without modifying files |
| `--help` | Show help (same as `help` command) |

---

## Commands

### flatten

Move all images from subdirectories into the current directory.

```bash
imtools flatten [--dry-run]
```

**Use case:** You downloaded images into nested folders and want them all in one place.

**Options:**

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be moved without moving |

**Example:**

```bash
# Before:
# ./vacation/beach/img1.jpg
# ./vacation/mountains/img2.png
# ./random/img3.gif

imtools flatten

# After:
# ./img1.jpg
# ./img2.png
# ./img3.gif
# (empty folders remain - use remove-empty-dirs to clean up)
```

**Supported formats:** PNG, JPEG, GIF, BMP, WebP, TIFF

---

### find-duplicates

Find duplicate images by comparing SHA256 hashes of file contents.

```bash
imtools find-duplicates [--delete]
```

**Use case:** Clean up duplicate wallpapers that may have different filenames.

**Options:**

| Option | Description |
|--------|-------------|
| `--delete` | Interactively prompt to delete duplicates (keeps first occurrence) |

**Example:**

```bash
# Find duplicates (report only)
imtools find-duplicates

# Output:
# Duplicate group (hash: a1b2c3d4e5f6...):
#   [0] wallpaper-001.png
#   [1] wallpaper-copy.png
#   [2] downloads/same-image.png

# Find and delete duplicates
imtools find-duplicates --delete
# Prompts: "Delete duplicates? Keep first file. [y/N]:"
```

**How it works:**
1. Recursively scans all image files
2. Computes SHA256 hash of each file's contents
3. Groups files with identical hashes
4. In delete mode, keeps the first file found and prompts for each group

---

### delete-portrait

Delete all portrait-oriented images (height > width).

```bash
imtools delete-portrait [--dry-run]
```

**Use case:** You only want landscape wallpapers for your desktop.

**Options:**

| Option | Description |
|--------|-------------|
| `--dry-run` | Show portrait images without deleting |

**Example:**

```bash
# Preview what would be deleted
imtools delete-portrait --dry-run

# Output:
# Portrait image: phone-wallpaper.jpg (1080x1920)
# Portrait image: screenshot.png (720x1280)
#
# Summary:
# Portrait images found: 2

# Actually delete
imtools delete-portrait
```

**How it works:** Reads image headers to extract dimensions without loading full images into memory.

---

### remove-empty-dirs

Recursively remove empty directories.

```bash
imtools remove-empty-dirs [--dry-run]
```

**Use case:** Clean up after `flatten` or manual file reorganization.

**Options:**

| Option | Description |
|--------|-------------|
| `--dry-run` | Show empty directories without removing |

**Example:**

```bash
# Preview
imtools remove-empty-dirs --dry-run

# Output:
# Would remove: vacation/beach
# Would remove: vacation/mountains
# Would remove: vacation

# Actually remove
imtools remove-empty-dirs
```

**How it works:** Runs multiple passes to handle nested empty directories (child dirs must be removed before parent becomes empty).

---

### convert-to-png

Convert all images to PNG format using ffmpeg.

```bash
imtools convert-to-png [--dry-run] [--delete]
```

**Use case:** Standardize your wallpaper collection to PNG format.

**Requirements:** `ffmpeg`

**Options:**

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be converted |
| `--delete` | Delete original files after successful conversion |

**Example:**

```bash
# Preview conversions
imtools convert-to-png --dry-run

# Convert and keep originals
imtools convert-to-png

# Convert and delete originals
imtools convert-to-png --delete
```

**Behavior:**
- Skips files already in PNG format
- Skips if output file already exists
- Converts: JPEG, GIF, BMP, WebP, TIFF

---

### download

Download wallpapers from wallhaven.cc.

```bash
imtools download --query <search> [options]
```

**Use case:** Quickly download wallpapers by search term.

**Requirements:** `ffmpeg`, `curl`

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--query <string>` | (required) | Search query |
| `--limit <number>` | 10 | Number of wallpapers to download |
| `--output <dir>` | `wallpapers` | Output directory |

**Example:**

```bash
# Download 10 nature wallpapers
imtools download --query "nature"

# Download 50 anime wallpapers to specific folder
imtools download --query "anime" --limit 50 --output ./anime-walls

# Download minimalist wallpapers
imtools download --query "minimalist dark"
```

**Behavior:**
- Scrapes wallhaven.cc search results
- Downloads full-resolution images
- Automatically converts JPG to PNG
- Skips already-downloaded images (by filename)

---

### sort

AI-powered image categorization using Ollama vision models.

```bash
imtools sort [options]
```

**Use case:** Automatically organize wallpapers into category folders.

**Requirements:** `curl`, `ollama` (running with a vision model)

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--dry-run` | false | Preview categorization without moving files |
| `--categories <list>` | auto | Comma-separated predefined categories |
| `--output <dir>` | `.` (current) | Output directory for sorted images |
| `--model <name>` | `moondream:1.8b` | Ollama vision model to use |
| `--workers <n>` | 4 | Parallel workers (max 16) |
| `--cooldown <ms>` | 2000 | Delay between batches |
| `--recursive` | true | Process subdirectories |
| `--no-recursive` | - | Only process current directory |

**Example:**

```bash
# Preview auto-categorization
imtools sort --dry-run

# Sort with predefined categories
imtools sort --categories "nature,anime,abstract,city,space"

# Sort to separate output directory
imtools sort --output ./sorted-wallpapers

# Use a different model
imtools sort --model llama3.2-vision:latest

# Faster processing (more workers, less cooldown)
imtools sort --workers 8 --cooldown 500
```

**Auto-detected categories:** When no `--categories` specified, automatically detects:
- Nature: mountains, forest, ocean, beach, sunset, flowers, etc.
- Space: galaxy, nebula, planets, astronaut, etc.
- Anime: anime, manga, waifu, chibi, etc.
- Fantasy: dragons, wizards, castles, mythical creatures, etc.
- Cyberpunk/Sci-fi: robots, futuristic, neon, hologram, etc.
- Animals, City, Architecture, Vehicles, and more...

See [AI Sorting Guide](ai-sorting.md) for detailed setup and model recommendations.

---

### help

Show help message with all commands and options.

```bash
imtools help
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (invalid arguments, file errors, etc.) |

---

## Common Workflows

### Clean Up Downloaded Wallpapers

```bash
cd ~/wallpapers

# 1. Flatten nested folders
imtools flatten

# 2. Remove empty directories
imtools remove-empty-dirs

# 3. Find and remove duplicates
imtools find-duplicates --delete

# 4. Remove portrait images (optional)
imtools delete-portrait --dry-run  # preview first
imtools delete-portrait
```

### Download and Organize

```bash
# Download
imtools download --query "nature landscape" --limit 100

# Organize with AI
cd wallpapers
imtools sort --categories "mountains,forest,ocean,sunset,abstract"
```

### Convert Collection to PNG

```bash
cd ~/wallpapers

# Preview first
imtools convert-to-png --dry-run

# Convert and clean up
imtools convert-to-png --delete
```

### Full Pipeline

```bash
# Download fresh wallpapers
imtools download --query "aesthetic" --limit 50 --output ./new-walls

# Process them
cd new-walls
imtools find-duplicates --delete
imtools delete-portrait
imtools convert-to-png --delete

# AI categorization
imtools sort
```

---

## Next Steps

- [AI Sorting Guide](ai-sorting.md) - Deep dive into AI categorization
- [Architecture](architecture.md) - Understand how imtools works internally
