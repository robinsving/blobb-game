"""Builds an animated form strip, assets/sprites/blobb_<name>.png, from ComfyUI frames on a black
background in assets/animations/<name>/<name>_frame_NNNN.png (e.g. grumpy, dash).
Same crop and frame size as BlobbSprite's other strips; colours matched to blobb_idle.png.

Usage: python3 tools/key_form.py NAME [preview.png] [--every=N] [--mirror]
  --every=N  keep every Nth frame (default 1)
  --mirror   flip the frames horizontally (when the clip faces the other way)
  --soft     alpha straight from brightness, no clean-up: keeps thin lines (e.g. reform, which starts
             as the scribble); colours are matched on the last frame (the whole Blobb) only
(needs numpy, scipy, pillow: e.g. uv run --with numpy --with scipy --with pillow python3 tools/key_form.py grumpy)
"""
import glob
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

FRAME_W, FRAME_H = 321, 305


def key_soft(path):
	a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
	alpha = np.clip((a.max(2) - 18.0) / 60.0, 0, 1)
	# edge pixels are the figure blended with the black: brighten them back, so no dark fringe
	# (only next to the background: the eyes and mouth inside are meant to be dark)
	near = ndimage.binary_dilation(a.max(2) < 18.0, iterations=4)
	t = np.where(near, np.clip(a.max(2) / 190.0, 0.05, 1.0), 1.0)[..., None]
	return np.dstack([np.clip(a / 255.0 / t, 0, 1), alpha])


def key(path):
	a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
	# black background: anything clearly brighter than the darkest border is Blobb (or his lines)
	border = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
	bg = np.median(border, 0)
	score = np.abs(a - bg).max(2)
	fg = score > 28
	# the clips carry blocky speckle round the outline: open it away before anything joins it up
	disk = ndimage.generate_binary_structure(2, 1)
	fg = ndimage.binary_opening(fg, disk, iterations=5)
	lab, n = ndimage.label(fg)
	if n:
		sizes = ndimage.sum(fg, lab, range(1, n + 1))
		keep = [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.02]
		fg = np.isin(lab, keep)
	fg = ndimage.binary_closing(fg, disk, iterations=4)
	fg = ndimage.binary_fill_holes(fg)
	fg = ndimage.gaussian_filter(fg.astype(np.float32), 2.5) > 0.5  # round the outline off
	alpha = ndimage.gaussian_filter(fg.astype(np.float32), 1.0)
	return np.dstack([a / 255.0, alpha])


def main():
	args = [a for a in sys.argv[1:] if not a.startswith('--')]
	every = int(next((a.split('=')[1] for a in sys.argv if a.startswith('--every=')), 1))
	mirror = '--mirror' in sys.argv
	soft = '--soft' in sys.argv
	name = args[0]
	paths = sorted(glob.glob('assets/animations/%s/%s_frame_*.png' % (name, name)))[::every]
	if not paths:
		sys.exit('no frames in assets/animations/%s/' % name)
	frames = [(key_soft if soft else key)(p) for p in paths]
	h, w, _ = frames[0].shape
	x0 = (w - FRAME_W) // 2  # the same crop as the idle/run/jump strips
	y0 = h - FRAME_H - 20
	strip = np.zeros((FRAME_H, FRAME_W * len(frames), 4), np.float32)
	for i, f in enumerate(frames):
		c = f[y0:y0 + FRAME_H, x0:x0 + FRAME_W]
		strip[:, i * FRAME_W:(i + 1) * FRAME_W] = c[:, ::-1] if mirror else c
	ref = np.asarray(Image.open('assets/sprites/blobb_idle.png').convert('RGBA')).astype(np.float32) / 255.0
	rm, sm = ref[..., 3] > 0.9, strip[..., 3] > 0.9
	if soft:  # match on the last frame only: the scribble's bright lines would skew the shift
		sm = sm.copy()
		sm[:, :FRAME_W * (len(frames) - 1)] = False
	for ch in range(3):
		r, x = ref[..., ch][rm], strip[..., ch][sm]
		strip[..., ch] = np.clip(strip[..., ch] - x.mean() + r.mean(), 0, 1)  # shift only: keeps the clip's crayon contrast
	out = 'assets/sprites/blobb_%s.png' % name
	from grid_strip import to_grid  # (wide strips become grids: WebGL texture size limits)
	to_grid(Image.fromarray((strip * 255).astype(np.uint8), 'RGBA')).save(out)
	print(out, len(frames), 'frames')
	if len(args) > 1:
		n = min(len(frames), 8)
		sheet = Image.new('RGBA', (FRAME_W * n, FRAME_H), (200, 200, 200, 255))
		for i in range(n):
			k = i * len(frames) // n
			fr = Image.fromarray((strip[:, k * FRAME_W:(k + 1) * FRAME_W] * 255).astype(np.uint8), 'RGBA')
			sheet.alpha_composite(fr, (i * FRAME_W, 0))
		sheet.save(args[1])


if __name__ == '__main__':
	main()
