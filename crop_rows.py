from PIL import Image

img = Image.open("cow_spritesheet.png")
w, h = img.size
print(f"Source: {w}x{h}, mode: {img.mode}")

sx = w / 945.0
sy = h / 2048.0
print(f"Scale: x={sx:.3f}, y={sy:.3f}")

rows_945 = {
    "row1_idle":    (40, 170, 900, 360),
    "row2_walk":    (35, 430, 910, 620),
    "row3_happy":   (45, 690, 890, 910),
    "row4_sleep":   (70, 1035, 850, 1200),
    "row5_carried": (90, 1330, 565, 1585),
}

for name, (l, t, r, b) in rows_945.items():
    box = (int(l*sx), int(t*sy), int(r*sx), int(b*sy))
    cropped = img.crop(box)
    out = f"cow_rows/{name}.png"
    cropped.save(out)
    print(f"  {name}: box={box} size={cropped.size} -> {out}")

print("Done!")
