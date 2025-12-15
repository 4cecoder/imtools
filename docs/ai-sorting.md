# AI-Powered Image Sorting Guide

Complete guide to setting up and using AI-powered image categorization with Ollama.

## Table of Contents

- [Overview](#overview)
- [How It Works](#how-it-works)
- [Setting Up Ollama](#setting-up-ollama)
- [Choosing a Vision Model](#choosing-a-vision-model)
- [Usage Examples](#usage-examples)
- [Auto-Detection Categories](#auto-detection-categories)
- [Custom Categories](#custom-categories)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)
- [Privacy & Security](#privacy--security)

---

## Overview

The `sort` command uses AI vision models running locally via [Ollama](https://ollama.ai) to analyze and categorize images. This is completely **local** and **private** - no images are sent to external servers.

**Key benefits:**
- Privacy: All processing happens on your machine
- No API costs: Run unlimited images for free
- Offline capable: Works without internet after model download
- Customizable: Choose models and categories

---

## How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Image     │────▶│   Ollama    │────▶│  Category   │
│  (base64)   │     │   Vision    │     │   Output    │
└─────────────┘     │   Model     │     └─────────────┘
                    └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │ "A mountain │
                    │  landscape  │
                    │  at sunset" │
                    └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │ Keyword     │
                    │ Matching    │──▶ Category: "mountains"
                    │ (mountain)  │
                    └─────────────┘
```

1. Image is converted to base64
2. Sent to local Ollama API with prompt "Describe this image"
3. Vision model returns description
4. Keywords extracted to determine category
5. Image moved to category folder

---

## Setting Up Ollama

### Installation

```bash
# Linux/macOS (official installer)
curl -fsSL https://ollama.ai/install.sh | sh

# Or via package managers:

# macOS (Homebrew)
brew install ollama

# Arch Linux
yay -S ollama

# NixOS
nix-env -iA nixpkgs.ollama
```

### Starting Ollama

```bash
# Start the Ollama service
ollama serve

# Or run in background
ollama serve &

# Check if running
curl http://localhost:11434/api/tags
```

### Pulling a Vision Model

```bash
# Default model (recommended for most users)
ollama pull moondream:1.8b

# Alternative models (see comparison below)
ollama pull llava:7b
ollama pull llava:13b
ollama pull llama3.2-vision:11b
```

---

## Choosing a Vision Model

### Model Comparison

| Model | Size | Speed | Accuracy | VRAM | Best For |
|-------|------|-------|----------|------|----------|
| `moondream:1.8b` | 1.7GB | Fast | Good | 4GB | Default, low-end hardware |
| `llava:7b` | 4.5GB | Medium | Better | 8GB | Balanced performance |
| `llava:13b` | 8GB | Slow | Best | 16GB | Maximum accuracy |
| `llama3.2-vision:11b` | 7GB | Medium | Excellent | 12GB | Latest tech |

### Recommendations

**Low-end hardware (4-8GB RAM, no GPU):**
```bash
ollama pull moondream:1.8b
imtools sort --model moondream:1.8b --workers 1
```

**Mid-range (16GB RAM, RTX 3060+):**
```bash
ollama pull llava:7b
imtools sort --model llava:7b --workers 4
```

**High-end (32GB RAM, RTX 4080+):**
```bash
ollama pull llava:13b
imtools sort --model llava:13b --workers 8
```

---

## Usage Examples

### Basic Usage

```bash
cd ~/wallpapers

# Preview what would happen
imtools sort --dry-run

# Actually sort images
imtools sort
```

### With Custom Output Directory

```bash
# Sort images into a separate "sorted" folder
imtools sort --output ./sorted-wallpapers
```

### With Predefined Categories

```bash
# Only sort into these specific categories
imtools sort --categories "nature,anime,abstract,city,space,gaming"
```

### Using Different Model

```bash
# Use more accurate (but slower) model
imtools sort --model llava:13b
```

### Adjusting Performance

```bash
# Faster (more parallel workers)
imtools sort --workers 8 --cooldown 200

# Slower but gentler on system
imtools sort --workers 1 --cooldown 5000
```

### Full Example

```bash
# Download some wallpapers first
imtools download --query "aesthetic landscape" --limit 50

# Sort them with AI
cd wallpapers
imtools sort \
    --categories "mountains,ocean,forest,sunset,city,abstract" \
    --model llava:7b \
    --workers 4 \
    --cooldown 1000
```

---

## Auto-Detection Categories

When you don't specify `--categories`, imtools automatically detects from 50+ categories:

### Nature & Landscapes

| Category | Keywords Detected |
|----------|-------------------|
| `mountains` | mountain, peak, cliff, canyon, volcano |
| `forest` | forest, woods, jungle, trees |
| `ocean` | ocean, sea, waves, underwater, coral |
| `beach` | beach, coast, shore, tropical, island |
| `lake` | lake, pond |
| `river` | river, stream |
| `waterfall` | waterfall, cascade |
| `sunset` | sunset, dusk, golden hour |
| `sunrise` | sunrise, dawn |
| `flowers` | flower, bloom, blossom, rose, garden |
| `winter` | snow, ice, frozen, glacier, blizzard |
| `desert` | desert, dune, sand, oasis |
| `sky` | sky, clouds, horizon |

### Space & Sci-Fi

| Category | Keywords Detected |
|----------|-------------------|
| `space` | galaxy, nebula, planet, cosmos, astronaut, satellite |
| `scifi` | robot, android, cyborg, futuristic, alien, laser |
| `cyberpunk` | cyberpunk, neon lights, hologram, dystopia |

### Art Styles

| Category | Keywords Detected |
|----------|-------------------|
| `anime` | anime, manga, waifu, chibi, kawaii |
| `fantasy` | dragon, wizard, elf, unicorn, castle, magical |
| `abstract` | fractal, geometric, spiral, kaleidoscope, pattern |
| `minimalist` | minimalist, minimal, simple, clean |
| `retro` | retro, vintage, nostalgic |

### Urban & Architecture

| Category | Keywords Detected |
|----------|-------------------|
| `city` | skyline, skyscraper, downtown, cityscape, urban |
| `street` | street, alley, road |
| `architecture` | cathedral, church, temple, palace, bridge, monument |

### Other

| Category | Keywords Detected |
|----------|-------------------|
| `animals` | specific animals (wolf, eagle, etc.) or generic "animal" |
| `vehicles` | car, motorcycle, plane, ship, train |
| `horror` | skull, zombie, vampire, ghost, haunted |
| `gaming` | gaming, game, video game, controller |
| `tech` | circuit, computer, programming, code, matrix |
| `music` | guitar, piano, violin, concert |
| `portrait` | woman, man, person, face, character |
| `night` | night, midnight, starry, moonlit |
| `neon` | neon, glowing, luminous |
| `dark` | dark, moody, gloomy, shadow |
| `colorful` | colorful, rainbow, vibrant |

### Fallback

Images that don't match any category go to `uncategorized/`.

---

## Custom Categories

### Simple Category List

```bash
imtools sort --categories "nature,anime,abstract"
```

The AI will try to match descriptions to your categories.

### Category Strategy

**Broad categories** (easier to match):
```bash
--categories "nature,art,urban,space"
```

**Specific categories** (more precise):
```bash
--categories "mountains,beach,sunset,anime,cyberpunk,minimalist"
```

### Tips for Custom Categories

1. **Use lowercase** - matching is case-insensitive
2. **Be specific** - "forest" is better than "green"
3. **Match keywords** - categories should match words the AI might say
4. **Include fallback** - consider adding "misc" or "other"

---

## Performance Tuning

### Workers

Controls parallel image processing:

```bash
--workers 1   # Sequential, lowest resource usage
--workers 4   # Default, good balance
--workers 8   # Faster, needs more VRAM
--workers 16  # Maximum, high-end systems only
```

### Cooldown

Delay between batches (in milliseconds):

```bash
--cooldown 500    # Fast, may overwhelm slower systems
--cooldown 2000   # Default, balanced
--cooldown 5000   # Gentle, for background processing
```

### Memory Considerations

| Workers | Approximate VRAM Usage |
|---------|------------------------|
| 1 | Base model size |
| 2-4 | +1-2GB |
| 8 | +3-4GB |
| 16 | +6-8GB |

### Recommended Configurations

**Background processing (laptop):**
```bash
imtools sort --workers 1 --cooldown 5000 --model moondream:1.8b
```

**Active processing (desktop):**
```bash
imtools sort --workers 4 --cooldown 1000 --model llava:7b
```

**Batch processing (server):**
```bash
imtools sort --workers 8 --cooldown 200 --model llava:13b
```

---

## Troubleshooting

### "Ollama is not available"

```
Error: Ollama is not available at http://localhost:11434
```

**Solutions:**
1. Start Ollama: `ollama serve`
2. Check if running: `curl http://localhost:11434/api/tags`
3. Check port: ensure nothing else uses 11434

### "Model not found"

```
Error analyzing image
```

**Solution:** Pull the model first:
```bash
ollama pull moondream:1.8b
```

### Slow Performance

1. Use smaller model: `--model moondream:1.8b`
2. Reduce workers: `--workers 1`
3. Increase cooldown: `--cooldown 5000`
4. Check system resources: `htop` or `nvidia-smi`

### Images Going to "uncategorized"

The AI couldn't match the description to any category.

**Solutions:**
1. Use `--dry-run` to see AI descriptions
2. Add more categories that match the descriptions
3. Use broader category names
4. Try a more accurate model

### Out of Memory

```
CUDA out of memory
```

**Solutions:**
1. Use smaller model
2. Reduce workers: `--workers 1`
3. Close other GPU applications
4. Use CPU-only mode (slower)

---

## Privacy & Security

### What Stays Local

- All images are processed locally
- Image data never leaves your machine
- No telemetry or analytics
- No internet required after model download

### Network Activity

The only network activity is:
1. Initial model download from Ollama
2. Local HTTP to `localhost:11434`

### Verifying Local Processing

```bash
# Check Ollama is only listening locally
netstat -tlnp | grep 11434
# Should show 127.0.0.1:11434

# Monitor network during sorting
# (should show no external connections)
```

### Air-Gapped Systems

For maximum security:
1. Download model on connected system
2. Copy model files to air-gapped system
3. Run Ollama and imtools offline

---

## Next Steps

- [Command Reference](commands.md) - All sort options
- [Architecture](architecture.md) - How the AI integration works
- [Packaging](packaging.md) - Include Ollama as dependency
