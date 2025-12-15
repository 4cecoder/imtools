# Gentoo Ebuild Installation

This directory contains ebuilds for installing imtools on Gentoo Linux.

## Ebuilds

- `imtools-1.0.0.ebuild` - Stable release (downloads from GitHub)
- `imtools-9999.ebuild` - Live/git version (builds from latest main branch)

## Quick Setup

### 1. Create Local Overlay

```bash
# Create overlay structure
sudo mkdir -p /var/db/repos/local/{metadata,profiles,media-gfx/imtools}
echo "local" | sudo tee /var/db/repos/local/profiles/repo_name
echo "masters = gentoo" | sudo tee /var/db/repos/local/metadata/layout.conf

# Register the overlay
sudo mkdir -p /etc/portage/repos.conf
cat <<EOF | sudo tee /etc/portage/repos.conf/local.conf
[local]
location = /var/db/repos/local
EOF
```

### 2. Install Ebuild

```bash
# Copy ebuild to overlay
sudo cp imtools-1.0.0.ebuild /var/db/repos/local/media-gfx/imtools/

# Generate manifest
cd /var/db/repos/local/media-gfx/imtools
sudo ebuild imtools-1.0.0.ebuild manifest

# Install
sudo emerge --ask media-gfx/imtools
```

### 3. For Live Ebuild (git master)

```bash
sudo cp imtools-9999.ebuild /var/db/repos/local/media-gfx/imtools/
cd /var/db/repos/local/media-gfx/imtools
sudo ebuild imtools-9999.ebuild manifest

# Unmask live ebuild
echo "media-gfx/imtools **" | sudo tee -a /etc/portage/package.accept_keywords

sudo emerge --ask media-gfx/imtools::local
```

## USE Flags

| Flag | Default | Description |
|------|---------|-------------|
| `ffmpeg` | Yes | Enable convert-to-png and download commands |
| `curl` | Yes | Enable download and sort commands |
| `ollama` | No | Enable AI-powered sort command |

```bash
# Example: disable ffmpeg
echo "media-gfx/imtools -ffmpeg" | sudo tee -a /etc/portage/package.use
```

## Dependencies

- **Build:** `dev-lang/zig` (must be installed manually or from overlay)
- **Runtime:** Optional, controlled by USE flags

## Installing Zig on Gentoo

Zig is not in the main Gentoo repository. Options:

1. **Binary download:**
   ```bash
   wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
   tar xf zig-linux-x86_64-0.13.0.tar.xz
   sudo mv zig-linux-x86_64-0.13.0 /opt/zig
   sudo ln -s /opt/zig/zig /usr/local/bin/zig
   ```

2. **GURU overlay:**
   ```bash
   sudo eselect repository enable guru
   sudo emerge --sync guru
   sudo emerge dev-lang/zig
   ```
