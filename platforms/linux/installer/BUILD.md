# Building the Linux DRL Community Installer

This guide explains how to build distributable AppImage and DEB packages for Linux.

## Quick Build

```bash
cd /path/to/DRL-Simulator-Community/platforms/linux
chmod +x build-appimage.sh
./build-appimage.sh
```

## Output Formats

### AppImage (Recommended)
- **Universal**: Runs on any Linux distribution
- **Portable**: Single executable file, no installation required
- **Self-contained**: Includes all dependencies

### DEB Package (Optional)
- **For**: Debian, Ubuntu, Linux Mint, Pop!_OS
- **Requires**: `dpkg-deb` tool
- **Installs to**: System directories

## Build Options

```bash
# Standard build (AppImage only)
./build-appimage.sh

# Custom version
./build-appimage.sh --version=2.0.0

# Also create DEB package
./build-appimage.sh --deb

# Combined
./build-appimage.sh --version=2.0.0 --deb
```

## Output Files

After building, find packages in `installer/output/`:

| File | Description |
|------|-------------|
| `DRL-Community-X.X.X-x86_64.AppImage` | Universal Linux package |
| `drl-community_X.X.X_amd64.deb` | Debian/Ubuntu package (if --deb) |

## Prerequisites

### Required
- `wget` - For downloading AppImage tools
- `file` - For file type detection
- `fuse` - For running AppImages

### Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt install wget file fuse libfuse2
```

**Fedora:**
```bash
sudo dnf install wget file fuse
```

**Arch Linux:**
```bash
sudo pacman -S wget file fuse2
```

## Using the AppImage

```bash
# Make executable and run
chmod +x DRL-Community-1.0.0-x86_64.AppImage
./DRL-Community-1.0.0-x86_64.AppImage

# Command-line options
./DRL-Community-1.0.0-x86_64.AppImage --server    # Start server only
./DRL-Community-1.0.0-x86_64.AppImage --install   # Install to system
./DRL-Community-1.0.0-x86_64.AppImage --diagnose  # Run diagnostics
```

## Support

- **GitHub**: [DRL-Simulator-Community](https://github.com/Georgeandrew7/DRL-Simulator-Community)
