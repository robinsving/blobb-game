"""Tiles screenshots into one image: python3 tools/contact_sheet.py OUT.png shot1.png shot2.png ..."""
import sys
from PIL import Image
out, files = sys.argv[1], sys.argv[2:]
cols = 3; tw, th = 640, 360
rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGB', (cols * tw, rows * th), (40, 0, 40))
for i, f in enumerate(files):
    im = Image.open(f).convert('RGB'); im.thumbnail((tw, th))
    sheet.paste(im, ((i % cols) * tw, (i // cols) * th))
sheet.save(out)
