#!/usr/bin/env python3
"""
Combine individual SAM-cropped frames into uniform-size horizontal strip spritesheets
for Godot AnimatedSprite2D (hframes). Each animation becomes one PNG strip.
Also generates a .tres SpriteFrames resource file for each animal.
"""
import os
from PIL import Image

BASE = "assets/characters"

animals = {
    "cow": {
        "idle":    ([f"cow/idle/cow_idle_{i}.png" for i in range(4)], 4),
        "walk":    ([f"cow/walk/cow_walk_{i}.png" for i in range(4)], 4),
        "happy":   ([f"cow/happy/cow_happy_{i}.png" for i in range(4)], 4),
        "sleep":   ([f"cow/sleep/cow_sleep_{i}.png" for i in range(2)], 2),
        "carried": ([f"cow/carried/cow_carried_{i}.png" for i in range(2)], 2),
    },
    "sheep": {
        "idle":    ([f"sheep/idle/sheep_idle_{i}.png" for i in range(4)], 4),
        "walk":    ([f"sheep/walk/sheep_walk_{i}.png" for i in range(4)], 4),
        "happy":   ([f"sheep/happy/sheep_happy_{i}.png" for i in range(4)], 4),
        "sleep":   ([f"sheep/sleep/sheep_sleep_{i}.png" for i in range(2)], 2),
        "carried": ([f"sheep/carried/sheep_carried_{i}.png" for i in range(2)], 2),
    },
}

for animal, anims in animals.items():
    print(f"\n=== {animal.upper()} ===")
    for anim_name, (frame_paths, count) in anims.items():
        # Load all frames
        frames = []
        for fp in frame_paths:
            full = os.path.join(BASE, fp)
            frames.append(Image.open(full).convert("RGBA"))

        # Find max width and height across frames
        max_w = max(f.width for f in frames)
        max_h = max(f.height for f in frames)

        # Create horizontal strip with uniform cell size
        strip_w = max_w * count
        strip_h = max_h
        strip = Image.new("RGBA", (strip_w, strip_h), (0, 0, 0, 0))

        for i, f in enumerate(frames):
            # Center each frame in its cell
            x_off = i * max_w + (max_w - f.width) // 2
            y_off = max_h - f.height  # bottom-align for ground contact
            strip.paste(f, (x_off, y_off), f)

        out_path = os.path.join(BASE, animal, f"{animal}_{anim_name}.png")
        strip.save(out_path)
        print(f"  {anim_name}: {count} frames, cell={max_w}x{max_h}, strip={strip_w}x{strip_h} -> {out_path}")

    # Generate .tres SpriteFrames resource
    tres_lines = ['[gd_resource type="SpriteFrames" format=3]', '']

    # Collect all texture resources
    ext_resources = []
    idx = 1
    anim_data = {}
    for anim_name, (frame_paths, count) in anims.items():
        png_file = f"{animal}_{anim_name}.png"
        res_path = f"res://assets/characters/{animal}/{png_file}"
        ext_resources.append(f'[ext_resource type="Texture2D" path="{res_path}" id="{idx}"]')
        anim_data[anim_name] = {"ext_id": idx, "frames": count}
        idx += 1

    # Build tres content
    tres = '[gd_resource type="SpriteFrames" load_steps={} format=3]\n\n'.format(len(ext_resources) + 1)
    for er in ext_resources:
        tres += er + "\n"
    tres += "\n[resource]\n"

    # Build animations array
    anim_entries = []
    for anim_name, info in anim_data.items():
        frames_str = "["
        for i in range(info["frames"]):
            region_x = i * 1  # We'll use AtlasTexture approach instead
            frames_str += '{\n"duration": 1.0,\n"texture": ExtResource("' + str(info["ext_id"]) + '")\n}'
            if i < info["frames"] - 1:
                frames_str += ", "
        frames_str += "]"

        entry = '{{\n"frames": [{frames}],\n"loop": true,\n"name": &"{name}",\n"speed": 8.0\n}}'.format(
            frames=", ".join([
                '{{"duration": 1.0, "texture": ExtResource("{id}")}}'.format(id=info["ext_id"])
                for _ in range(info["frames"])
            ]),
            name=anim_name,
        )
        anim_entries.append(entry)

    tres += "animations = [{}]\n".format(", ".join(anim_entries))

    tres_path = os.path.join(BASE, animal, f"{animal}_sprites.tres")
    with open(tres_path, "w") as f:
        f.write(tres)
    print(f"  Resource: {tres_path}")

print("\nDone!")
