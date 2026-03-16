#!/usr/bin/env python3
"""
Extract UI buttons from a mobile app mockup.
Simple crop-based extraction with clean edges.
"""
import os
from PIL import Image

def main():
    input_path = "ui_buttons.png"
    output_dir = "./ui_buttons_output"
    
    img = Image.open(input_path)
    print(f"Image size: {img.size}")
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Define button regions (left, top, right, bottom)
    # Fine-tuned for clean button extraction
    buttons = {
        "start_bot": [100, 630, 1390, 800],      # 绿色 Start Bot
        "wallet": [100, 840, 1390, 1010],        # 蓝色 Wallet
        "invite_friends": [100, 1050, 1390, 1220], # 橙色 Invite Friends
        "tasks": [100, 1260, 1390, 1430],        # 紫色 Tasks
        "upgrade": [100, 1470, 1390, 1640],      # 黄色 Upgrade
        "settings": [100, 1680, 1390, 1850],     # 深灰 Settings
    }
    
    for name, coords in buttons.items():
        left, top, right, bottom = coords
        button_img = img.crop((left, top, right, bottom))
        
        # Save as PNG
        output_path = os.path.join(output_dir, f"{name}.png")
        button_img.save(output_path, "PNG")
        print(f"✓ {name}: {button_img.size[0]}x{button_img.size[1]} -> {output_path}")
    
    print(f"\nDone! 6 buttons extracted to: {output_dir}/")

if __name__ == "__main__":
    main()
