#!/usr/bin/env python3
"""Regenerate the AppIcon asset set from Design/Chatgo.png.

The source artwork is a white-ground CHAT monogram. iOS app icons must be
opaque, so the image is flattened to RGB before resampling.

Usage:
    python3 Design/make_icons.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Design" / "Chatgo.png"
OUTPUT = ROOT / "Sources" / "MyApp" / "Assets.xcassets" / "AppIcon.appiconset"

SIZES = {
    "Icon-20@2x.png": 40,
    "Icon-20@3x.png": 60,
    "Icon-29@2x.png": 58,
    "Icon-29@3x.png": 87,
    "Icon-40@2x.png": 80,
    "Icon-40@3x.png": 120,
    "Icon-60@2x.png": 120,
    "Icon-60@3x.png": 180,
    "Icon-1024.png": 1024,
}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    image = Image.open(SOURCE).convert("RGB")
    master = image.resize((1024, 1024), Image.LANCZOS)
    master.save(OUTPUT / "Icon-1024.png", format="PNG", optimize=True)
    for name, size in SIZES.items():
        if size == 1024:
            continue
        master.resize((size, size), Image.LANCZOS).save(
            OUTPUT / name, format="PNG", optimize=True
        )
    print(f"wrote {len(SIZES)} icons to {OUTPUT}")


if __name__ == "__main__":
    main()
