#!/usr/bin/env python3
"""
Generate macOS .icns and Windows .ico from a source image.
The source image is expected to contain the icon in the center; we crop
a centered square and fill transparent corners with a matching blue gradient
so the icon fills the entire app icon area.
"""
import os
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ICONS_DIR = Path(__file__).parent.parent / "src-tauri" / "icons"
SOURCE = ICONS_DIR / "source-icon.png"

if not SOURCE.exists():
    print(f"Source icon not found: {SOURCE}")
    sys.exit(1)

img = Image.open(SOURCE).convert("RGBA")
w, h = img.size

# Crop the largest centered square
size = min(w, h)
left = (w - size) // 2
top = (h - size) // 2
square = img.crop((left, top, left + size, top + size))

# Create a blue gradient background that fills the whole square.
# Sample the main blue colors from the center area of the source icon.
bg = Image.new("RGBA", (size, size), (37, 99, 235, 255))  # blue-600 base

# Build a radial-ish gradient from top-right to bottom-left matching the source feel
for y in range(size):
    for x in range(size):
        # Normalized coordinates
        nx = x / size
        ny = y / size
        # Light source from top-right
        t = (nx * 0.6 + (1 - ny) * 0.4)
        r = int(56 + t * 90)
        g = int(139 + t * 90)
        b = int(245 + t * 10)
        bg.putpixel((x, y), (r, g, b, 255))

# Composite source onto background using alpha channel
bg.paste(square, (0, 0), square)

# Save new square source
new_source = ICONS_DIR / "source-icon-square.png"
bg.save(new_source)
print(f"Saved square source: {new_source}")

# Generate sizes
SIZES = [16, 32, 64, 128, 256, 512, 1024]
for s in SIZES:
    resized = bg.resize((s, s), Image.LANCZOS)
    resized.save(ICONS_DIR / f"icon-{s}.png")
    print(f"Saved icon-{s}.png")

# 32x32 and 128x128 named files used by tauri.conf.json
bg.resize((32, 32), Image.LANCZOS).save(ICONS_DIR / "32x32.png")
bg.resize((128, 128), Image.LANCZOS).save(ICONS_DIR / "128x128.png")

# Generate .icns for macOS
iconset_dir = ICONS_DIR / "icon.iconset"
iconset_dir.mkdir(exist_ok=True)
for s in [16, 32, 64, 128, 256, 512, 1024]:
    bg.resize((s, s), Image.LANCZOS).save(iconset_dir / f"icon_{s}x{s}.png")
    if s <= 512:
        bg.resize((s * 2, s * 2), Image.LANCZOS).save(iconset_dir / f"icon_{s}x{s}@2x.png")

os.system(f"iconutil -c icns -o {ICONS_DIR / 'icon.icns'} {iconset_dir}")
os.system(f"rm -rf {iconset_dir}")
print(f"Generated icon.icns")

# Generate .ico for Windows
ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
frames = [bg.resize(s, Image.LANCZOS) for s in ico_sizes]
frames[0].save(
    ICONS_DIR / "icon.ico",
    format="ICO",
    sizes=ico_sizes,
    append_images=frames[1:],
)
print(f"Generated icon.ico")

print("Done.")
