"""Repacks Blobb's animation strips (one row of 321x305 frames) into grids no wider than 4096 px,
because many browsers/GPUs (WebGL) can't load a texture wider than 8192 (some 4096). The frame
count must split evenly into the columns (BlobbSprite.build_frames() reads columns x rows).

Usage: python3 tools/grid_strip.py assets/sprites/blobb_idle.png [...]   (rewrites them in place)
Also used by key_form.py as to_grid().
"""
import sys
from PIL import Image

FRAME_W, FRAME_H, MAX_W = 321, 305, 4096


def to_grid(im):
	cols_now, rows_now = im.width // FRAME_W, round(im.height / FRAME_H)
	n = cols_now * rows_now
	if im.width <= MAX_W:
		return im
	frames = [im.crop(((i % cols_now) * FRAME_W, (i // cols_now) * FRAME_H, (i % cols_now + 1) * FRAME_W, (i // cols_now + 1) * FRAME_H)) for i in range(n)]
	fits = MAX_W // FRAME_W
	cols = next((c for c in range(fits, 1, -1) if n % c == 0), None)
	if cols is None:  # a prime count: drop the last frame
		frames = frames[:-1]
		n -= 1
		cols = next(c for c in range(fits, 1, -1) if n % c == 0)
	rows = n // cols
	out = Image.new('RGBA', (cols * FRAME_W, rows * FRAME_H), (0, 0, 0, 0))
	for i, f in enumerate(frames):
		out.paste(f, ((i % cols) * FRAME_W, (i // cols) * FRAME_H))
	return out


if __name__ == '__main__':
	for p in sys.argv[1:]:
		im = Image.open(p).convert('RGBA')
		g = to_grid(im)
		if g is not im:
			g.save(p)
		print(p, im.size, '->', g.size)
