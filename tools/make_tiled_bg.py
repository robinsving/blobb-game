"""Makes a background seamlessly tileable horizontally by appending its mirror image.
Usage: python3 tools/make_tiled_bg.py IN OUT"""
import sys
from PIL import Image, ImageOps
im = Image.open(sys.argv[1]).convert('RGB')
out = Image.new('RGB', (im.width * 2, im.height))
out.paste(im, (0, 0)); out.paste(ImageOps.mirror(im), (im.width, 0))
out.save(sys.argv[2])
