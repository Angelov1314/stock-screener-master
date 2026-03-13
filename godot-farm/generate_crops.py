#!/usr/bin/env python3
"""
Crop Sprite Generator for Godot Farm Game
Style: Hand-drawn storybook like Tsuki Adventure
"""

from PIL import Image, ImageDraw
import math
import os

# Output directory
OUTPUT_DIR = "/Users/jerry/.openclaw/workspace/godot-farm/assets/crops"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Color Palette (Warm & Cozy)
COLORS = {
    'outline': '#3B2B1A',      # Dark warm brown
    'sage_green': '#7A9E7E',   # Sage
    'olive_green': '#5A7D3A',  # Olive
    'pumpkin_orange': '#FF8C42',  # Muted pumpkin
    'tomato_red': '#E84A3C',   # Soft tomato
    'strawberry_red': '#E84A5F',  # Strawberry
    'corn_yellow': '#F5D76E',  # Corn
    'wheat_gold': '#E6C875',   # Wheat
    'warm_brown': '#8B6F47',   # Warm earth
    'cream': '#FDF6E3',        # Cream
    'soil': '#6B4423',         # Dark soil
}

def create_image(size=64):
    """Create transparent image"""
    return Image.new('RGBA', (size, size), (0, 0, 0, 0))

def draw_ellipse(draw, xy, fill, outline=None, width=2):
    """Draw ellipse with outline"""
    draw.ellipse(xy, fill=fill, outline=outline, width=width)

def draw_line(draw, xy, fill, width=2):
    """Draw line"""
    draw.line(xy, fill=fill, width=width)

def draw_seed(draw, crop_name):
    """Draw seed stage - small seed on soil with tiny sprout"""
    cx, cy = 32, 50
    
    # Soil mound
    draw.ellipse([cx-10, cy, cx+10, cy+6], fill=COLORS['soil'], outline=COLORS['outline'], width=1)
    
    # Seed
    seed_color = COLORS['wheat_gold'] if crop_name == 'wheat' else COLORS['pumpkin_orange']
    draw.ellipse([cx-3, cy-2, cx+3, cy+3], fill=seed_color, outline=COLORS['outline'], width=1)
    
    # Tiny sprout emerging
    green = COLORS['sage_green']
    draw.line([(cx, cy-2), (cx-1, cy-8)], fill=green, width=2)
    draw.line([(cx, cy-2), (cx+2, cy-7)], fill=green, width=2)
    
    # Tiny leaf
    draw.ellipse([cx-3, cy-10, cx+1, cy-8], fill=green, outline=COLORS['outline'], width=1)

def draw_sprout(draw, crop_name):
    """Draw sprout stage - young plant with small leaves"""
    cx, cy = 32, 52
    
    # Soil mound
    draw.ellipse([cx-12, cy-2, cx+12, cy+4], fill=COLORS['soil'], outline=COLORS['outline'], width=1)
    
    # Stem
    green = COLORS['sage_green']
    draw.line([(cx, cy), (cx, cy-18)], fill=green, width=3)
    
    # Small leaves
    if crop_name in ['carrot', 'strawberry']:
        # Feathery/rounded leaves
        for i, dx in enumerate([-6, -2, 2, 6]):
            dy = -15 - (i % 2) * 3
            draw.ellipse([cx+dx-3, cy+dy-2, cx+dx+3, cy+dy+2], 
                        fill=green, outline=COLORS['outline'], width=1)
    elif crop_name == 'tomato':
        # Rounded leaves
        for dx in [-5, 0, 5]:
            draw.ellipse([cx+dx-4, cy-20, cx+dx+4, cy-14], 
                        fill=green, outline=COLORS['outline'], width=1)
    elif crop_name == 'corn':
        # Long leaves
        for dx in [-5, 0, 5]:
            draw.polygon([(cx+dx, cy-5), (cx+dx-3, cy-22), (cx+dx+3, cy-22)], 
                        fill=green, outline=COLORS['outline'])
    else:  # wheat
        # Thin grass-like
        for dx in [-4, 0, 4]:
            draw.line([(cx, cy), (cx+dx, cy-20)], fill=green, width=2)

def draw_growing(draw, crop_name):
    """Draw growing stage - developing plant"""
    cx, cy = 32, 52
    
    # Soil mound
    draw.ellipse([cx-14, cy-2, cx+14, cy+4], fill=COLORS['soil'], outline=COLORS['outline'], width=1)
    
    if crop_name == 'carrot':
        # Taller with visible orange hint
        green = COLORS['olive_green']
        draw.line([(cx, cy), (cx, cy-30)], fill=green, width=4)
        # Feathery leaves
        for i in range(5):
            dx = (i - 2) * 5
            dy = -25 - (i % 2) * 5
            draw.ellipse([cx+dx-4, cy+dy-3, cx+dx+4, cy+dy+3], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'], width=1)
        # Orange root tip peeking through
        draw.ellipse([cx-4, cy-2, cx+4, cy+5], fill=COLORS['pumpkin_orange'], 
                    outline=COLORS['outline'], width=1)
    
    elif crop_name == 'wheat':
        # Multiple stems developing
        for offset in [-6, 0, 6]:
            draw.line([(cx+offset, cy), (cx+offset, cy-35)], 
                     fill=COLORS['wheat_gold'], width=3)
            # Developing grain heads
            for i in range(3):
                dy = cy - 30 - i * 6
                draw.ellipse([cx+offset-3, dy-3, cx+offset+3, dy+3], 
                            fill=COLORS['wheat_gold'], outline=COLORS['outline'], width=1)
        # Green base
        for offset in [-6, 0, 6]:
            draw.line([(cx+offset, cy), (cx+offset, cy-15)], 
                     fill=COLORS['sage_green'], width=3)
    
    elif crop_name == 'tomato':
        # Vine with small green tomatoes
        green = COLORS['olive_green']
        draw.line([(cx, cy), (cx, cy-35)], fill=green, width=4)
        draw.line([(cx, cy-20), (cx+10, cy-28)], fill=green, width=3)
        draw.line([(cx, cy-25), (cx-10, cy-32)], fill=green, width=3)
        # Leaves
        for dx in [-8, 0, 8, 12]:
            dy = -18 if dx > 0 else -30
            draw.ellipse([cx+dx-4, cy+dy-3, cx+dx+4, cy+dy+3], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'], width=1)
        # Small green tomatoes
        for dx, dy in [(8, -28), (-8, -32), (0, -22)]:
            draw.ellipse([cx+dx-4, cy+dy-4, cx+dx+4, cy+dy+4], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'], width=1)
    
    elif crop_name == 'strawberry':
        # Bushy with small green strawberries
        green = COLORS['olive_green']
        draw.line([(cx, cy), (cx, cy-25)], fill=green, width=4)
        draw.line([(cx, cy-15), (cx-8, cy-22)], fill=green, width=3)
        draw.line([(cx, cy-18), (cx+8, cy-25)], fill=green, width=3)
        # Leaves
        for dx in [-10, -3, 3, 10]:
            dy = -20 if abs(dx) < 5 else -25
            draw.ellipse([cx+dx-4, cy+dy-2, cx+dx+4, cy+dy+3], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'], width=1)
        # Small green strawberries
        for dx, dy in [(6, -22), (-6, -20)]:
            draw.polygon([(cx+dx, cy+dy), (cx+dx-3, cy+dy-5), (cx+dx+3, cy+dy-5)], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'])
    
    elif crop_name == 'corn':
        # Tall stalk with developing ear
        green = COLORS['olive_green']
        draw.line([(cx, cy), (cx, cy-45)], fill=green, width=5)
        # Leaves
        for dy in [-10, -20, -30]:
            draw.polygon([(cx, cy+dy), (cx-15, cy+dy-5), (cx-12, cy+dy+5)], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'])
            draw.polygon([(cx, cy+dy), (cx+15, cy+dy-5), (cx+12, cy+dy+5)], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'])
        # Developing ear
        draw.ellipse([cx-5, cy-35, cx+5, cy-20], fill=COLORS['corn_yellow'], 
                    outline=COLORS['outline'], width=2)
        # Husk
        draw.polygon([(cx, cy-22), (cx-3, cy-38), (cx+3, cy-38)], 
                    fill=COLORS['sage_green'], outline=COLORS['outline'])

def draw_mature(draw, crop_name):
    """Draw mature stage - fully grown, ripe crop"""
    cx, cy = 32, 52
    
    # Soil mound
    draw.ellipse([cx-14, cy-2, cx+14, cy+4], fill=COLORS['soil'], outline=COLORS['outline'], width=1)
    
    if crop_name == 'carrot':
        # Full carrot with leafy top
        green = COLORS['olive_green']
        # Carrot body (orange)
        draw.polygon([(cx-6, cy), (cx+6, cy), (cx+2, cy-20), (cx-2, cy-20)], 
                    fill=COLORS['pumpkin_orange'], outline=COLORS['outline'], width=2)
        # Carrot lines
        draw.line([(cx-3, cy-5), (cx-1, cy-5)], fill=COLORS['outline'], width=1)
        draw.line([(cx-2, cy-12), (cx+1, cy-12)], fill=COLORS['outline'], width=1)
        # Leafy top
        for i in range(6):
            angle = (i / 6) * math.pi
            dx = math.cos(angle) * 12
            dy = -22 - math.sin(angle) * 8
            draw.ellipse([cx+dx-4, cy+dy-3, cx+dx+4, cy+dy+3], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'], width=1)
        draw.line([(cx, cy-18), (cx, cy-28)], fill=green, width=3)
    
    elif crop_name == 'wheat':
        # Golden wheat stalks
        for offset in [-8, 0, 8]:
            # Stalk
            draw.line([(cx+offset, cy), (cx+offset, cy-42)], 
                     fill=COLORS['wheat_gold'], width=3)
            # Grain heads (heavy with grain)
            for i in range(4):
                dy = cy - 35 - i * 5
                size = 4 - i * 0.5
                draw.ellipse([cx+offset-size, dy-size, cx+offset+size, dy+size], 
                            fill=COLORS['wheat_gold'], outline=COLORS['outline'], width=1)
        # Green base fading to gold
        for offset in [-8, 0, 8]:
            draw.line([(cx+offset, cy), (cx+offset, cy-12)], 
                     fill=COLORS['sage_green'], width=3)
    
    elif crop_name == 'tomato':
        # Vine with red tomatoes
        green = COLORS['olive_green']
        draw.line([(cx, cy), (cx, cy-38)], fill=green, width=4)
        draw.line([(cx, cy-22), (cx+12, cy-30)], fill=green, width=3)
        draw.line([(cx, cy-28), (cx-10, cy-36)], fill=green, width=3)
        # Leaves
        for dx in [-10, 0, 10, 14]:
            dy = -18 if dx > 0 else -35
            draw.ellipse([cx+dx-4, cy+dy-3, cx+dx+4, cy+dy+3], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'], width=1)
        # Ripe red tomatoes
        for dx, dy in [(10, -30), (-8, -36), (0, -25)]:
            draw.ellipse([cx+dx-5, cy+dy-5, cx+dx+5, cy+dy+5], 
                        fill=COLORS['tomato_red'], outline=COLORS['outline'], width=2)
            # Tomato shine
            draw.ellipse([cx+dx-2, cy+dy-3, cx+dx, cy+dy-1], fill=(255,255,255,100))
    
    elif crop_name == 'strawberry':
        # Bushy with red strawberries
        green = COLORS['olive_green']
        draw.line([(cx, cy), (cx, cy-28)], fill=green, width=4)
        draw.line([(cx, cy-12), (cx-10, cy-20)], fill=green, width=3)
        draw.line([(cx, cy-16), (cx+10, cy-24)], fill=green, width=3)
        # Leaves
        for dx in [-12, -4, 4, 12]:
            dy = -18 if abs(dx) < 6 else -24
            draw.ellipse([cx+dx-4, cy+dy-2, cx+dx+4, cy+dy+3], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'], width=1)
        # Red strawberries (heart shape)
        for dx, dy in [(8, -20), (-6, -18)]:
            # Heart shape using two circles and triangle
            draw.polygon([(cx+dx, cy+dy), (cx+dx-4, cy+dy-3), (cx+dx+4, cy+dy-3)], 
                        fill=COLORS['strawberry_red'], outline=COLORS['outline'])
            draw.ellipse([cx+dx-4, cy+dy-6, cx+dx, cy+dy-2], 
                        fill=COLORS['strawberry_red'], outline=COLORS['outline'])
            draw.ellipse([cx+dx, cy+dy-6, cx+dx+4, cy+dy-2], 
                        fill=COLORS['strawberry_red'], outline=COLORS['outline'])
            # Seeds
            for sx, sy in [(-1, -3), (1, -3), (0, -5)]:
                draw.point([cx+dx+sx, cy+dy+sy], fill=COLORS['cream'])
            # Leaf cap
            draw.polygon([(cx+dx, cy+dy-6), (cx+dx-3, cy+dy-9), (cx+dx+3, cy+dy-9)], 
                        fill=green, outline=COLORS['outline'])
    
    elif crop_name == 'corn':
        # Tall stalk with ripe corn
        green = COLORS['olive_green']
        draw.line([(cx, cy), (cx, cy-50)], fill=green, width=5)
        # Large leaves
        for dy in [-12, -25, -38]:
            draw.polygon([(cx, cy+dy), (cx-18, cy+dy-6), (cx-14, cy+dy+6)], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'])
            draw.polygon([(cx, cy+dy), (cx+18, cy+dy-6), (cx+14, cy+dy+6)], 
                        fill=COLORS['sage_green'], outline=COLORS['outline'])
        # Ripe corn ear
        draw.ellipse([cx-6, cy-40, cx+6, cy-22], fill=COLORS['corn_yellow'], 
                    outline=COLORS['outline'], width=2)
        # Corn kernel lines
        for i in range(3):
            y = cy - 36 + i * 5
            draw.arc([cx-5, y-2, cx+5, y+4], 0, 180, fill=COLORS['outline'], width=1)
        # Husk
        draw.polygon([(cx, cy-22), (cx-4, cy-42), (cx+4, cy-42)], 
                    fill=COLORS['olive_green'], outline=COLORS['outline'])
        # Silk tassels
        draw.line([(cx, cy-42), (cx-2, cy-48)], fill=COLORS['wheat_gold'], width=2)
        draw.line([(cx, cy-42), (cx+2, cy-48)], fill=COLORS['wheat_gold'], width=2)

# Generate all sprites
crops = ['wheat', 'carrot', 'strawberry', 'tomato', 'corn']
stages = ['seed', 'sprout', 'growing', 'mature']

manifest = []

for crop in crops:
    crop_dir = os.path.join(OUTPUT_DIR, crop)
    os.makedirs(crop_dir, exist_ok=True)
    
    for stage in stages:
        img = create_image(64)
        draw = ImageDraw.Draw(img)
        
        # Draw based on stage
        if stage == 'seed':
            draw_seed(draw, crop)
        elif stage == 'sprout':
            draw_sprout(draw, crop)
        elif stage == 'growing':
            draw_growing(draw, crop)
        elif stage == 'mature':
            draw_mature(draw, crop)
        
        # Save
        filename = f"{crop}_{stage}.png"
        filepath = os.path.join(crop_dir, f"{stage}.png")
        img.save(filepath, 'PNG')
        print(f"Created: {filepath}")
        
        manifest.append({
            "id": f"{crop}_{stage}",
            "path": f"assets/crops/{crop}/{stage}.png",
            "type": "crop_sprite",
            "size": [64, 64],
            "pivot": [32, 56],
            "crop_id": crop,
            "stage": stage
        })

print(f"\nGenerated {len(manifest)} crop sprites!")
