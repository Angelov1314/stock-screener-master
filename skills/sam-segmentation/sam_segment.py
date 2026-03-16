#!/usr/bin/env python3
"""
SAM Segmentation Pipeline
Extracts objects from sprite sheets with background removal
"""
from PIL import Image
import numpy as np
import cv2
import os
import argparse
from typing import List, Optional, Tuple

# Optional SAM import
try:
    from segment_anything import sam_model_registry, SamAutomaticMaskGenerator
    SAM_AVAILABLE = True
except ImportError:
    SAM_AVAILABLE = False
    print("⚠️  SAM not available, will use fallback contour detection")


class SAMSegmenter:
    """SAM-based image segmentation for sprite sheets"""
    
    def __init__(self, use_sam: bool = True, device: str = "cpu"):
        self.mask_generator = None
        self.device = device
        
        if use_sam and SAM_AVAILABLE:
            self._load_sam()
    
    def _load_sam(self):
        """Load SAM model"""
        checkpoint = os.path.expanduser("~/.cache/sam/sam_vit_h.pth")
        
        if not os.path.exists(checkpoint):
            print("📥 Downloading SAM checkpoint...")
            os.makedirs(os.path.dirname(checkpoint), exist_ok=True)
            import urllib.request
            url = "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth"
            urllib.request.urlretrieve(url, checkpoint)
            print("✅ Downloaded")
        
        sam = sam_model_registry["vit_h"](checkpoint=checkpoint)
        sam.to(device=self.device)
        self.mask_generator = SamAutomaticMaskGenerator(sam)
        print("✅ SAM loaded")
    
    def segment(
        self,
        image_path: str,
        output_dir: str,
        names: List[str],
        min_area: int = 30000,
        max_area: int = 500000,
        output_size: int = 256,
        padding: int = 30
    ) -> List[str]:
        """
        Segment image and save objects
        
        Args:
            image_path: Path to input image
            output_dir: Directory to save output
            names: List of names for output files
            min_area: Minimum object area
            max_area: Maximum object area
            output_size: Output canvas size
            padding: Padding around object
            
        Returns:
            List of saved file paths
        """
        os.makedirs(output_dir, exist_ok=True)
        
        # Load image
        img = Image.open(image_path).convert("RGB")
        img_np = np.array(img)
        
        print(f"📷 Image: {img.size}")
        
        # Detect objects
        if self.mask_generator:
            objects = self._segment_sam(img_np, min_area, max_area)
        else:
            objects = self._segment_contour(img_np, min_area)
        
        if not objects:
            print("⚠️  No objects found, trying vertical split...")
            objects = self._vertical_split(img)
        
        print(f"✅ Found {len(objects)} objects")
        
        # Sort by Y position
        objects.sort(key=lambda x: x[0])
        
        # Save each object
        saved_files = []
        for i, (y_pos, obj_img) in enumerate(objects):
            name = names[i] if i < len(names) else f"object_{i:02d}"
            
            # Center and save
            centered = self._center_on_canvas(
                obj_img, output_size, padding
            )
            
            output_path = os.path.join(output_dir, f"{name}.png")
            centered.save(output_path)
            saved_files.append(output_path)
            print(f"  💾 {name}.png")
        
        return saved_files
    
    def _segment_sam(
        self,
        img_np: np.ndarray,
        min_area: int,
        max_area: int
    ) -> List[Tuple[int, Image.Image]]:
        """Segment using SAM"""
        masks = self.mask_generator.generate(img_np)
        
        objects = []
        for mask_data in masks:
            area = mask_data['area']
            if min_area < area < max_area:
                mask = mask_data['segmentation']
                
                # Create RGBA
                rgba = np.zeros((*img_np.shape[:2], 4), dtype=np.uint8)
                rgba[:, :, :3] = img_np
                rgba[:, :, 3] = mask.astype(np.uint8) * 255
                
                # Find bounds
                coords = np.where(mask)
                if len(coords[0]) == 0:
                    continue
                
                y_center = int(coords[0].mean())
                
                # Crop with padding
                y_min, y_max = coords[0].min(), coords[0].max()
                x_min, x_max = coords[1].min(), coords[1].max()
                pad = 30
                
                y_min = max(0, y_min - pad)
                y_max = min(img_np.shape[0], y_max + pad)
                x_min = max(0, x_min - pad)
                x_max = min(img_np.shape[1], x_max + pad)
                
                cropped = rgba[y_min:y_max, x_min:x_max]
                objects.append((y_center, Image.fromarray(cropped)))
        
        return objects
    
    def _segment_contour(
        self,
        img_np: np.ndarray,
        min_area: int
    ) -> List[Tuple[int, Image.Image]]:
        """Segment using contour detection"""
        gray = cv2.cvtColor(img_np, cv2.COLOR_RGB2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        edges = cv2.Canny(blurred, 30, 100)
        
        kernel = np.ones((5, 5), np.uint8)
        dilated = cv2.dilate(edges, kernel, iterations=2)
        
        contours, _ = cv2.findContours(
            dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
        )
        
        objects = []
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if area > min_area:
                x, y, w, h = cv2.boundingRect(cnt)
                
                # Create mask
                mask = np.zeros(img_np.shape[:2], dtype=np.uint8)
                cv2.drawContours(mask, [cnt], -1, 255, -1)
                
                # Refine mask
                kernel = np.ones((3, 3), np.uint8)
                mask = cv2.erode(mask, kernel, iterations=1)
                
                # Create RGBA
                rgba = np.zeros((*img_np.shape[:2], 4), dtype=np.uint8)
                rgba[:, :, :3] = img_np
                rgba[:, :, 3] = mask
                
                # Crop
                pad = 40
                y1 = max(0, y - pad)
                y2 = min(img_np.shape[0], y + h + pad)
                x1 = max(0, x - pad)
                x2 = min(img_np.shape[1], x + w + pad)
                
                cropped = rgba[y1:y2, x1:x2]
                y_center = y + h // 2
                objects.append((y_center, Image.fromarray(cropped)))
        
        return objects
    
    def _vertical_split(
        self,
        img: Image.Image
    ) -> List[Tuple[int, Image.Image]]:
        """Fallback: simple vertical split"""
        # Detect sections by finding horizontal gaps
        gray = np.array(img.convert('L'))
        
        # Project onto Y axis
        y_proj = np.mean(gray, axis=1)
        
        # Find gaps (low values)
        threshold = 250
        is_gap = y_proj > threshold
        
        # Find section boundaries
        sections = []
        in_section = False
        start = 0
        
        for i, gap in enumerate(is_gap):
            if not gap and not in_section:
                start = i
                in_section = True
            elif gap and in_section:
                sections.append((start, i))
                in_section = False
        
        if in_section:
            sections.append((start, len(is_gap)))
        
        # Extract sections
        objects = []
        for y1, y2 in sections:
            section = img.crop((0, y1, img.width, y2))
            section = self._remove_white_bg(section)
            y_center = (y1 + y2) // 2
            objects.append((y_center, section))
        
        return objects
    
    def _remove_white_bg(
        self,
        img: Image.Image,
        threshold: int = 240
    ) -> Image.Image:
        """Remove white/gray background"""
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        data = np.array(img)
        r, g, b, a = data.T
        
        white = (r > threshold) & (g > threshold) & (b > threshold)
        data[..., 3][white.T] = 0
        
        return Image.fromarray(data)
    
    def _center_on_canvas(
        self,
        img: Image.Image,
        target_size: int,
        padding: int
    ) -> Image.Image:
        """Center image on transparent canvas"""
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        # Find content bounds
        alpha = np.array(img)[:, :, 3]
        coords = np.where(alpha > 20)
        
        if len(coords[0]) > 0:
            y_min, y_max = coords[0].min(), coords[0].max()
            x_min, x_max = coords[1].min(), coords[1].max()
            img = img.crop((x_min, y_min, x_max, y_max))
        
        # Scale to fit
        max_size = target_size - (padding * 2)
        scale = min(
            max_size / img.width,
            max_size / img.height,
            1.0
        )
        
        new_w = int(img.width * scale)
        new_h = int(img.height * scale)
        img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Center
        canvas = Image.new('RGBA', (target_size, target_size), (0, 0, 0, 0))
        x = (target_size - new_w) // 2
        y = (target_size - new_h) // 2
        canvas.paste(img, (x, y), img)
        
        return canvas


def main():
    parser = argparse.ArgumentParser(
        description='SAM Segmentation Pipeline'
    )
    parser.add_argument('--input', '-i', required=True, help='Input image')
    parser.add_argument('--output', '-o', required=True, help='Output directory')
    parser.add_argument('--names', '-n', required=True, 
                        help='Comma-separated names for output files')
    parser.add_argument('--min-area', type=int, default=30000)
    parser.add_argument('--max-area', type=int, default=500000)
    parser.add_argument('--size', type=int, default=256, help='Output size')
    parser.add_argument('--padding', type=int, default=30)
    parser.add_argument('--no-sam', action='store_true', 
                        help='Disable SAM, use contour detection only')
    
    args = parser.parse_args()
    
    names = [n.strip() for n in args.names.split(',')]
    
    segmenter = SAMSegmenter(use_sam=not args.no_sam)
    
    segmenter.segment(
        image_path=args.input,
        output_dir=args.output,
        names=names,
        min_area=args.min_area,
        max_area=args.max_area,
        output_size=args.size,
        padding=args.padding
    )


if __name__ == "__main__":
    main()
