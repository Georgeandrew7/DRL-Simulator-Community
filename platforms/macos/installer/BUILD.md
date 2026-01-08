# Building the macOS DRL Community Installer

This guide explains how to build distributable `.pkg` and `.dmg` installers for macOS.

## Prerequisites

### Required Tools (Built into macOS)
- `pkgbuild` - Creates component packages
- `productbuild` - Creates product archives with installer UI
- `hdiutil` - Creates disk images (DMG)

### Optional Tools
- **Xcode Command Line Tools**: `xcode-select --install`
- **Developer ID Certificate**: For signing (distribution outside Mac App Store)

## Quick Build

```bash
cd /path/to/DRL-Simulator-Community/platforms/macos
chmod +x build-installer.sh
./build-installer.sh
```

## Build Options

```bash
# Standard build (unsigned)
./build-installer.sh

# Signed build (for distribution)
./build-installer.sh --sign "Developer ID Installer: Your Name (TEAM_ID)"

# Custom version
./build-installer.sh --version "2.0.0"

# Skip DMG creation
./build-installer.sh --no-dmg
```

## Output Files

After building, you'll find in `installer/output/`:

| File | Description |
|------|-------------|
| `DRL-Community-X.X.X.pkg` | macOS Installer Package |
| `DRL-Community-X.X.X.dmg` | Disk Image (for distribution) |
| `build.log` | Build log with timestamps |

## What the Installer Does

### Pre-Installation
1. Checks for existing DRL Simulator installation
2. Backs up existing configuration
3. Verifies system requirements (macOS 10.15+)

### Installation Steps
1. Copies server files to `/usr/local/drl-community/`
2. Installs BepInEx to game directory
3. Compiles and installs plugins
4. Adds hosts file entry (`127.0.0.1 api.drlgame.com`)
5. Creates "DRL Offline Mode.app" in Applications

### Post-Installation
1. Sets correct permissions
2. Creates command-line shortcuts (`drl-server`, `drl-diagnose`)
3. Offers to start the mock server

## Signing for Distribution

### Get a Developer ID Certificate

1. Enroll in [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)
2. Create "Developer ID Installer" certificate in Xcode or developer portal
3. Install certificate in Keychain

### Sign the Package

```bash
# Find your signing identity
security find-identity -v -p basic

# Build with signing
./build-installer.sh --sign "Developer ID Installer: Your Name (XXXXXXXXXX)"
```

### Notarization (Required for macOS 10.15+)

```bash
# Submit for notarization
xcrun notarytool submit DRL-Community-1.0.0.pkg \
    --apple-id "your@email.com" \
    --password "app-specific-password" \
    --team-id "XXXXXXXXXX" \
    --wait

# Staple the ticket
xcrun stapler staple DRL-Community-1.0.0.pkg
```

## Customization

### Custom Background Image

Place a PNG image at:
```
installer/resources/background.png
```
Recommended size: 660x418 pixels

### Custom License

Edit the license file at:
```
installer/resources/license.txt
```

### Custom Welcome Text

Edit the welcome file at:
```
installer/resources/welcome.txt
```

## Troubleshooting

### "Unidentified Developer" Warning

Users can bypass by:
1. Right-click the .pkg → Open
2. Or: System Preferences → Security & Privacy → Open Anyway

For production, sign and notarize the package.

### Build Fails with Permission Error

```bash
sudo chown -R $(whoami) installer/output
chmod +x build-installer.sh
```

### pkgbuild Not Found

Install Xcode Command Line Tools:
```bash
xcode-select --install
```

## Package Structure

```
DRL-Community-1.0.0.pkg
├── Distribution           # Installer configuration
├── Resources/
│   ├── background.png    # Installer background
│   ├── license.txt       # License agreement
│   └── welcome.txt       # Welcome message
└── drl-community.pkg     # Component package
    ├── Payload/          # Files to install
    ├── Scripts/
    │   ├── preinstall    # Pre-installation script
    │   └── postinstall   # Post-installation script
    └── Bom               # Bill of materials
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-07 | Initial release |

## Support

- **GitHub Issues**: [DRL-Simulator-Community](https://github.com/Georgeandrew7/DRL-Simulator-Community/issues)
- **Discord**: DRL Community Server

---

*Built with ❤️ for the DRL Community*
