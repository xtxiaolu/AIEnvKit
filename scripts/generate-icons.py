#!/usr/bin/env python3
"""
Generate macOS .icns and Windows .ico from a source image.
The source image contains a rounded-square icon with transparent corners.
We crop a centered square and fill the transparent corners by extrapolating
from the *inner* part of the rounded square (ignoring the outer glow/highlight),
so the corners blend naturally without a visible seam.
"""
import os
import sys
from pathlib import Path
import numpy as np
from PIL import Image

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

# Work at 512x512 for speed/quality balance
work_size = 512
square_small = square.resize((work_size, work_size), Image.LANCZOS)
arr = np.array(square_small).astype(np.float32)
alpha = arr[:, :, 3]

# Original shape mask
shape_mask = alpha > 20.0

# Inner mask: erode shape to avoid the outer glow/highlight ring
try:
    from scipy.ndimage import binary_erosion
    inner_mask = binary_erosion(shape_mask, iterations=10)
except ImportError:
    inner_mask = shape_mask.copy()
    for _ in range(10):
        padded = np.pad(inner_mask, 1, mode='constant', constant_values=False)
        inner_mask = (
            padded[0:-2, 1:-1] & padded[1:-1, 0:-2] & padded[1:-1, 1:-1]
            & padded[1:-1, 2:] & padded[2:, 1:-1]
        )

# Use the average color of the inner area as the corner fill
avg_r = int(np.median(arr[inner_mask, 0]))
avg_g = int(np.median(arr[inner_mask, 1]))
avg_b = int(np.median(arr[inner_mask, 2]))
print(f"Corner fill color (median inner): ({avg_r}, {avg_g}, {avg_b})")

out = arr.copy()
out[:, :, 3] = 255.0

# Fill transparent corners with the solid inner color
fill_mask = ~shape_mask
out[fill_mask, 0] = avg_r
out[fill_mask, 1] = avg_g
out[fill_mask, 2] = avg_b

# Convert to image and scale to final size
filled_img_small = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
filled_img = filled_img_small.resize((size, size), Image.LANCZOS)

# Save new square source
new_source = ICONS_DIR / "source-icon-square.png"
filled_img.save(new_source)
print(f"Saved square source: {new_source}")

# Generate sizes (skip 32 and 128; we create 32x32.png and 128x128.png separately)
SIZES = [16, 64, 256, 512, 1024]
for s in SIZES:
    resized = filled_img.resize((s, s), Image.LANCZOS)
    resized.save(ICONS_DIR / f"icon-{s}.png")
    print(f"Saved icon-{s}.png")

# 32x32 and 128x128 named files used by tauri.conf.json
filled_img.resize((32, 32), Image.LANCZOS).save(ICONS_DIR / "32x32.png")
print("Saved 32x32.png")
filled_img.resize((128, 128), Image.LANCZOS).save(ICONS_DIR / "128x128.png")
print("Saved 128x128.png")

# Generate .icns for macOS
iconset_dir = ICONS_DIR / "icon.iconset"
iconset_dir.mkdir(exist_ok=True)
for s in [16, 32, 64, 128, 256, 512, 1024]:
    filled_img.resize((s, s), Image.LANCZOS).save(iconset_dir / f"icon_{s}x{s}.png")
    if s <= 512:
        filled_img.resize((s * 2, s * 2), Image.LANCZOS).save(iconset_dir / f"icon_{s}x{s}@2x.png")

os.system(f"iconutil -c icns -o {ICONS_DIR / 'icon.icns'} {iconset_dir}")
os.system(f"rm -rf {iconset_dir}")
print(f"Generated icon.icns")

# Generate .ico for Windows
ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
frames = [filled_img.resize(s, Image.LANCZOS) for s in ico_sizes]
frames[0].save(
    ICONS_DIR / "icon.ico",
    format="ICO",
    sizes=ico_sizes,
    append_images=frames[1:],
)
print(f"Generated icon.ico")

print("Done.")
