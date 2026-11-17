"""Cuts the figures out of the original crayon drawing (assets/drawing.jpeg) into
assets/sprites/drawn_*.png, so the game can use the child's own versions of Blobb.

Usage: python3 tools/cut_drawing.py [preview.png]   (needs numpy, scipy, pillow)

How it works: the paper's brightness is estimated locally (it is unevenly lit), every
pixel's "ink amount" relative to that paper becomes alpha, and the ink colour is
un-mixed from the paper. Characters ("sticker") also get a soft paper-coloured fill
behind the pencil strokes, like a figure cut out of the page with scissors, so they
read well on any background. Scribbles and speed lines stay see-through.
"""
import sys
import numpy as np
from PIL import Image, ImageOps
from scipy import ndimage

SRC = 'assets/drawing.jpeg'
OUT = 'assets/sprites/drawn_%s.png'

# name: (box x0, y0, x1, y1 in the upright 1920x1080 photo, ink filter, sticker fill, max size, ink gain)
#   ink filter: 'all' | 'color' (drop grey pencil) | 'grey' (drop coloured pencil)
FIGURES = {
	'blobb':     ((895, 555, 1200, 840), 'all', True, 420, 1.0),     # the classic: fuzzy, purple eyes, blue feet
	'superjump': ((1190, 380, 1370, 595), 'all', True, 360, 1.0),    # stretched mid-air, legs trailing
	'blue':      ((1295, 590, 1525, 825), 'all', True, 420, 1.6),    # blue, open-mouthed, dark legs
	'dash':      ((1570, 610, 1850, 800), 'all', True, 420, 1.0),    # a green blur with speed lines, face out front
	'ball':      ((600, 640, 845, 875), 'color', True, 360, 1.0),    # a round green scribble, no face, no legs
	'grumpy':    ((275, 745, 525, 1000), 'all', True, 420, 1.0),     # spiky dark crown, angry brows, jagged teeth
	'scribble':  ((320, 258, 905, 770), 'grey', False, 700, 4.0),    # the big grey scribble-burst
	'title':     ((680, 130, 1075, 260), 'all', False, 900, 3.0),    # BLOBB in blue crayon letters
}
# silhouette threshold (fraction of the strongest blurred ink); lower for faintly drawn figures
SOLID = {'blue': 0.2, 'grumpy': 0.2}


def load():
	im = ImageOps.exif_transpose(Image.open(SRC)).convert('RGB')
	assert im.size == (1920, 1080), im.size
	return np.asarray(im).astype(np.float32) / 255.0


def paper_estimate(a):
	"""Local paper colour: a big max-filter (paper is the brightest thing nearby), smoothed."""
	# work at 1/4 size: the filter must be wider than the biggest figure
	small = a[::4, ::4]
	out = np.empty_like(a)
	for c in range(3):
		m = ndimage.maximum_filter(small[..., c], size=41)
		m = ndimage.gaussian_filter(m, 10)
		out[..., c] = ndimage.zoom(m, 4, order=1)[:a.shape[0], :a.shape[1]]
	return np.maximum(out, 0.3)


def cut(name, a, paper, box, ink_filter, sticker, max_size, gain):
	x0, y0, x1, y1 = box
	obs = a[y0:y1, x0:x1]
	pap = paper[y0:y1, x0:x1]
	norm = np.clip(obs / pap, 0, 1)  # white-balanced against the local paper
	diff = 1 - norm
	alpha = np.clip((diff.max(2) - 0.12) * 3.5 * gain, 0, 1)
	sat = norm.max(2) - norm.min(2)
	if ink_filter == 'color':
		alpha *= np.clip((sat - 0.06) * 12, 0, 1)
	elif ink_filter == 'grey':
		alpha *= np.clip((0.08 - sat) * 25, 0, 1)
	alpha = ndimage.gaussian_filter(alpha, 0.6)
	# un-mix against white paper: norm = 1*(1-a) + ink*a, then a little more saturated
	a3 = np.maximum(alpha[..., None], 0.15)
	ink = np.clip((norm - (1 - a3)) / a3, 0, 1)
	g = ink.mean(2, keepdims=True)
	ink = np.clip(g + (ink - g) * 1.3, 0, 1)
	if name == 'title':
		ink *= 0.7  # the letters were drawn very lightly; press a little harder
	if ink_filter == 'grey':
		ink[:] = (0.2, 0.2, 0.22)  # graphite; un-mixing faint grey lines leaves light fringes

	if sticker:
		# a blurred ink map is robust to gaps in the hatching
		blur = ndimage.gaussian_filter(alpha, 7)
		solid = blur > SOLID.get(name, 0.3) * blur.max()
		# close bites out of the edge where the pencil was light (padded so borders don't stick)
		yy, xx = np.mgrid[-14:15, -14:15]
		disk = xx * xx + yy * yy <= 14 * 14
		solid = ndimage.binary_closing(np.pad(solid, 20), structure=disk)[20:-20, 20:-20]
		solid = ndimage.binary_fill_holes(solid)
		lab, n = ndimage.label(solid)
		if n:
			sizes = ndimage.sum(solid, lab, range(1, n + 1))
			keep = [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.15]
			solid = np.isin(lab, keep)
		solid = ndimage.binary_opening(solid, iterations=2)
		fill = ndimage.gaussian_filter(solid.astype(np.float32), 1.5) * 0.95
		paper_col = np.array([0.98, 0.97, 0.94], np.float32)
		out_a = alpha + fill * (1 - alpha)
		rgb = (ink * alpha[..., None] + paper_col * (fill * (1 - alpha))[..., None]) / np.maximum(out_a[..., None], 1e-4)
		# strays outside the silhouette (smudges, other figures' strokes) fade out
		near = ndimage.gaussian_filter(ndimage.binary_dilation(solid, iterations=10).astype(np.float32), 3)
		out_a *= near
	else:
		out_a, rgb = alpha, ink

	rgba = np.dstack([rgb, out_a])
	ys, xs = np.where(out_a > 0.04)
	rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
	im = Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA')
	im.thumbnail((max_size, max_size), Image.LANCZOS)
	return im


def main():
	a = load()
	paper = paper_estimate(a)
	ims = {}
	for name, (box, f, sticker, size, gain) in FIGURES.items():
		ims[name] = cut(name, a, paper, box, f, sticker, size, gain)
		ims[name].save(OUT % name)
		print(name, ims[name].size)
	if len(sys.argv) > 1:  # preview sheet on a mid-grey and a forest-green background
		w = sum(i.width for i in ims.values()) + 20 * len(ims)
		h = max(i.height for i in ims.values())
		sheet = Image.new('RGB', (w, h * 2), (128, 128, 128))
		sheet.paste((40, 90, 50), (0, h, w, h * 2))
		x = 0
		for i in ims.values():
			sheet.paste(i, (x, 0), i)
			sheet.paste(i, (x, h), i)
			x += i.width + 20
		sheet.save(sys.argv[1])


if __name__ == '__main__':
	main()
