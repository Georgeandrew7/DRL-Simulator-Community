# Icon Placeholder

Replace this file with a proper `.ico` file for the installer.

## Requirements

- Format: Windows Icon (.ico)
- Recommended sizes: 16x16, 32x32, 48x48, 256x256 (multi-resolution)
- Theme: Drone racing / gaming

## Creating an Icon

### Option 1: Online Converter
1. Create or find a PNG image (256x256 or larger)
2. Use https://convertico.com/ or https://icoconvert.com/
3. Save as `icon.ico` in this folder

### Option 2: Using ImageMagick
```bash
convert logo.png -define icon:auto-resize=256,128,64,48,32,16 icon.ico
```

### Option 3: Using GIMP
1. Open your image in GIMP
2. File → Export As → icon.ico
3. Select sizes to include

## Suggested Icon Ideas

- Drone silhouette
- Racing flag
- Game controller with drone
- "DRL" text logo
