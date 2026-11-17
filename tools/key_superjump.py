"""Builds assets/sprites/blobb_superjump.png from the later jump frames in
assets/animations/jumping/ (19..33: Blobb crouches, then stretches into a long tilted
oval with his legs trailing, like the little flying Blobb in the original drawing).
Those frames have a baked-in beige paper background, so they're keyed by colour distance.

Usage: python3 tools/key_superjump.py [preview.png]   (needs numpy, scipy, pillow)
Output frames are FRAME_W x FRAME_H to match BlobbSprite's other strips.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

# 28-29 key badly (paper between the legs), 33 is half-faded
FRAMES = [24, 25, 26, 27, 30, 31, 32]
SRC = 'assets/animations/jumping/jumping_frame_%04d.png'
OUT = 'assets/sprites/blobb_superjump.png'
FRAME_W, FRAME_H = 321, 305


def key(path):
	a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
	h, w, _ = a.shape
	border = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3), a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
	bg = np.median(border, 0)
	# the paper is slightly vignetted: compare chroma more than brightness
	d = a - bg
	chroma = np.abs(d - d.mean(2, keepdims=True)).max(2)
	dark = np.clip(-d.mean(2), 0, None)
	score = chroma * 1.6 + dark
	fg = score > 22
	fg = ndimage.binary_opening(fg, iterations=1)
	fg = ndimage.binary_closing(fg, iterations=3)
	fg = ndimage.binary_fill_holes(fg)
	lab, n = ndimage.label(fg)
	sizes = ndimage.sum(fg, lab, range(1, n + 1))
	keep = [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.03]
	fg = np.isin(lab, keep)
	alpha = ndimage.gaussian_filter(fg.astype(np.float32), 1.0)
	return np.dstack([a / 255.0, alpha])


def main():
	frames = [key(SRC % f) for f in FRAMES]
	h, w, _ = frames[0].shape
	# one crop for all frames so motion inside the frame is kept; feet near the bottom
	x0 = (w - FRAME_W) // 2
	y0 = h - FRAME_H - 20
	strip = np.zeros((FRAME_H, FRAME_W * len(frames), 4), np.float32)
	for i, f in enumerate(frames):
		# the source frames lean up-LEFT; mirror them so he stretches toward the right like the strips' facing
		strip[:, i * FRAME_W:(i + 1) * FRAME_W] = f[y0:y0 + FRAME_H, x0:x0 + FRAME_W][:, ::-1]
	# these frames came out paler than the other strips: match their mean/spread per channel
	ref = np.asarray(Image.open('assets/sprites/blobb_jumping.png').convert('RGBA')).astype(np.float32) / 255.0
	rm = ref[..., 3] > 0.9
	sm = strip[..., 3] > 0.9
	for c in range(3):
		r, x = ref[..., c][rm], strip[..., c][sm]
		strip[..., c] = np.clip((strip[..., c] - x.mean()) * (r.std() / x.std()) + r.mean(), 0, 1)
	im = Image.fromarray((strip * 255).astype(np.uint8), 'RGBA')
	im.save(OUT)
	print(OUT, im.size, 'frames', len(frames))
	if len(sys.argv) > 1:
		prev = Image.new('RGB', im.size, (60, 110, 70))
		prev.paste(im, (0, 0), im)
		prev.save(sys.argv[1])


if __name__ == '__main__':
	main()
