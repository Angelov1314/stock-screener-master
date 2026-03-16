from PIL import Image
import os, sys

src = "/Users/jerry/Downloads/Gemini_Generated_Image_utkkxyutkkxyutkk.png"
img = Image.open(src)
w, h = img.size
print(f"Source: {w}x{h}, mode: {img.mode}")

# Coordinates estimated from the 1408x3050 image
rows = {
    "row1_idle":    (40, 100, 1350, 430),
    "row2_walk":    (30, 500, 1360, 820),
    "row3_happy":   (30, 890, 1370, 1340),
    "row4_sleep":   (60, 1400, 1320, 1720),
    "row5_carried": (170, 1880, 1160, 2500),
}

outdir = "/Users/jerry/.openclaw/workspace/godot-farm/assets/characters/sheep"
os.makedirs(outdir, exist_ok=True)

for name, box in rows.items():
    cropped = img.crop(box)
    out = os.path.join(outdir, f"{name}.png")
    cropped.save(out)
    print(f"  {name}: box={box} size={cropped.size} -> {out}")

print("Done cropping rows!")
