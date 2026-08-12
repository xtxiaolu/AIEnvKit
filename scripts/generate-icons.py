#!/usr/bin/env python3
"""
Generate all application icons from source-icon.png.

The source image is expected to contain a rounded-square icon with transparent
or semi-transparent corners (e.g. a glow on a transparent background). We crop
to the visible bounds of that icon, center it on a transparent square canvas,
and emit square PNGs/ICNS/ICO that keep the rounded outline instead of filling
the corners with a solid color.
"""
import io
import os
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ICONS_DIR = Path(__file__).parent.parent / "src-tauri" / "icons"
SOURCE = ICONS_DIR / "source-icon.png"

if not SOURCE.exists():
    print(f"Source icon not found: {SOURCE}")
    sys.exit(1)


def crop_to_fill_square(
    img: Image.Image, target_size: int = 1024, alpha_threshold: int = 20
) -> Image.Image:
    """Crop to the visible icon and scale it so the icon fills the square canvas."""
    arr = np.array(img.convert("RGBA"))
    alpha = arr[:, :, 3]

    visible = alpha > alpha_threshold
    if not np.any(visible):
        raise ValueError("Source image appears to be fully transparent")

    ys, xs = np.where(visible)
    left = int(xs.min())
    top = int(ys.min())
    right = int(xs.max()) + 1
    bottom = int(ys.max()) + 1

    cropped = img.crop((left, top, right, bottom))
    crop_w, crop_h = cropped.size

    # Scale so the smaller dimension of the crop fills the target square,
    # then center-crop the excess. This makes the icon extend to the edges
    # without leaving transparent margins.
    scale = target_size / min(crop_w, crop_h)
    scaled_w = int(round(crop_w * scale))
    scaled_h = int(round(crop_h * scale))
    scaled = cropped.resize((scaled_w, scaled_h), Image.LANCZOS)

    square = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    offset_x = (target_size - scaled_w) // 2
    offset_y = (target_size - scaled_h) // 2
    square.paste(scaled, (offset_x, offset_y), scaled)
    return square


def save_ico(path: Path, images: list[Image.Image]) -> None:
    """Write a multi-size Windows ICO file using PNG-encoded frames.

    Pillow's built-in ICO writer in this environment only preserves a single
    frame when append_images is used, so we assemble the ICO container manually.
    """
    png_bytes = []
    for img in images:
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        png_bytes.append(buf.getvalue())

    count = len(images)
    with open(path, "wb") as f:
        # ICONDIR: reserved(2), type(2), count(2)
        f.write(struct.pack("<HHH", 0, 1, count))

        # ICONDIRENTRY list
        offset = 6 + 16 * count
        for img, data in zip(images, png_bytes):
            w, h = img.size
            wb = w if w < 256 else 0
            hb = h if h < 256 else 0
            f.write(struct.pack("<BBBBHHII", wb, hb, 0, 0, 1, 32, len(data), offset))
            offset += len(data)

        # Image data
        for data in png_bytes:
            f.write(data)


# ---------------------------------------------------------------------------
# Build the master transparent square from source-icon.png
# ---------------------------------------------------------------------------
img = Image.open(SOURCE).convert("RGBA")
print(f"Source size: {img.size}")

# Start from the largest centered square so the icon is centered and balanced
size = min(img.size)
left = (img.width - size) // 2
top = (img.height - size) // 2
square = img.crop((left, top, left + size, top + size))

# Crop tightly to the visible icon and scale it to fill a transparent square
master = crop_to_fill_square(square, target_size=1024)
print(f"Master square size: {master.size}")

# Save the new square source (transparent corners, no fill)
new_source = ICONS_DIR / "source-icon-square.png"
master.save(new_source)
print(f"Saved square source: {new_source}")

# ---------------------------------------------------------------------------
# Generate PNG sizes
# ---------------------------------------------------------------------------
SIZES = [16, 64, 256, 512, 1024]
for s in SIZES:
    master.resize((s, s), Image.LANCZOS).save(ICONS_DIR / f"icon-{s}.png")
    print(f"Saved icon-{s}.png")

# 32x32 and 128x128 named files used by tauri.conf.json
master.resize((32, 32), Image.LANCZOS).save(ICONS_DIR / "32x32.png")
print("Saved 32x32.png")
master.resize((128, 128), Image.LANCZOS).save(ICONS_DIR / "128x128.png")
print("Saved 128x128.png")

# ---------------------------------------------------------------------------
# Generate .icns for macOS
# ---------------------------------------------------------------------------
iconset_dir = ICONS_DIR / "icon.iconset"
iconset_dir.mkdir(exist_ok=True)
for s in [16, 32, 64, 128, 256, 512, 1024]:
    master.resize((s, s), Image.LANCZOS).save(iconset_dir / f"icon_{s}x{s}.png")
    if s <= 512:
        master.resize((s * 2, s * 2), Image.LANCZOS).save(
            iconset_dir / f"icon_{s}x{s}@2x.png"
        )

os.system(f"iconutil -c icns -o {ICONS_DIR / 'icon.icns'} {iconset_dir}")
os.system(f"rm -rf {iconset_dir}")
print("Generated icon.icns")

# ---------------------------------------------------------------------------
# Generate .ico for Windows
# ---------------------------------------------------------------------------
ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
ico_frames = [master.resize(s, Image.LANCZOS) for s in ico_sizes]
save_ico(ICONS_DIR / "icon.ico", ico_frames)
print("Generated icon.ico")

print("Done.")
