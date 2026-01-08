# Windows Installer Build Instructions

## Prerequisites

1. **Inno Setup 6.x** - Download from https://jrsoftware.org/isinfo.php
2. **Icon file** - Create or download an icon for the installer

## Building the Installer

### Option 1: Using Inno Setup GUI

1. Open Inno Setup Compiler
2. Open `DRL-Community.iss`
3. Click **Build** → **Compile**
4. The installer will be created in `installer/output/`

### Option 2: Using Command Line

```batch
:: From the platforms/windows directory
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" DRL-Community.iss
```

### Option 3: Using the Build Script

```batch
build-installer.bat
```

## Output

The compiled installer will be saved as:
```
installer/output/DRL-Community-Setup-1.0.0.exe
```

## Before Building

1. Make sure all source files are in place:
   - `common/` directory with all Python scripts
   - `docs/` directory with documentation
   - `LICENSE` file in repository root

2. Create an icon file:
   - Save as `installer/icon.ico`
   - Recommended size: 256x256 pixels
   - Can use any drone/racing themed icon

3. Update version number:
   - Edit `#define MyAppVersion "1.0.0"` in `DRL-Community.iss`

## Customization

### Change Install Components

Edit the `[Components]` section in `DRL-Community.iss`

### Change Default Tasks

Edit the `[Tasks]` section - add/remove `Flags: unchecked` to change defaults

### Add More Files

Add entries to the `[Files]` section

## Testing

1. Build the installer
2. Run it on a clean Windows VM or system
3. Verify all components install correctly
4. Test the uninstaller
5. Check that hosts file is properly modified

## Signing (Optional)

For production releases, sign the installer with a code signing certificate:

```batch
signtool sign /f certificate.pfx /p password /t http://timestamp.digicert.com "installer/output/DRL-Community-Setup-1.0.0.exe"
```
