"""Cuts the banana creature out of assets/blobb_enemy_base.jpeg (grey studio background).
Usage: python3 tools/key_banana.py   (needs numpy, scipy, pillow)"""
import numpy as np
from PIL import Image
from scipy import ndimage
a = np.asarray(Image.open('assets/blobb_enemy_base.jpeg').convert('RGB')).astype(np.int32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
sat = a.max(2) - a.min(2)
greyish = sat < 34
lab, n = ndimage.label(greyish)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
bg = np.isin(lab, list(border))
fg = ~bg
lab2, n2 = ndimage.label(fg)
sizes = ndimage.sum(fg, lab2, range(1, n2 + 1))
fg = lab2 == (np.argmax(sizes) + 1)
fg = ndimage.binary_fill_holes(fg)
fg = ndimage.binary_opening(fg, iterations=2)
alpha = ndimage.gaussian_filter(fg.astype(float), 1.0)
rgba = np.dstack([a.astype(np.uint8), (alpha * 255).astype(np.uint8)])
yy, xx = np.where(alpha > 0.05)
im = Image.fromarray(rgba).crop((xx.min(), yy.min(), xx.max() + 1, yy.max() + 1))
im.thumbnail((400, 600))
im.save('assets/sprites/banana.png')
print(im.size)
