"""Synthesises the spiky Blobb's sounds into assets/audio/:
  bristle.wav    the spikes shoot out: a quick rising zing with little clicks (one per spike)
  unbristle.wav  they sink back in: a soft falling "pfff" and a small settle
Usage: python3 tools/gen_bristle.py   (needs numpy)"""
import numpy as np, wave
SR = 44100
rng = np.random.default_rng(5)

def t(d): return np.linspace(0, d, int(SR * d), endpoint=False)
def save(name, x, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    with wave.open(f'assets/audio/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
def sweep(f0, f1, d, curve=1.0):
    k = np.linspace(0, 1, int(SR * d)) ** curve
    return 2 * np.pi * np.cumsum(f0 + (f1 - f0) * k) / SR
def lp(x, k): return np.convolve(x, np.ones(k) / k, mode='same')

# bristle: a springy zing up, a bright edge (a few odd harmonics), and spike clicks on the way up
d = 0.32; x = t(d)
ph = sweep(260, 1500, d, 0.6)
zing = (np.sin(ph) + 0.35 * np.sin(3 * ph) + 0.15 * np.sin(5 * ph)) * np.exp(-x * 7) * np.minimum(1, x / 0.004)
clicks = np.zeros_like(x)
for i, at in enumerate([0.02, 0.05, 0.075, 0.1, 0.12, 0.14]):
    n = int(at * SR); m = int(0.012 * SR)
    clicks[n:n + m] += rng.uniform(-1, 1, m) * np.exp(-np.arange(m) / (0.002 * SR)) * (0.9 - i * 0.08)
thump = np.sin(2 * np.pi * 110 * x) * np.exp(-x * 30)
save('bristle', zing * 0.8 + clicks * 0.7 + thump * 0.5, 0.75)

# unbristle: air out (soft filtered noise, falling), a gentle falling tone, a little bump at the end
d = 0.5; x = t(d)
air = lp(rng.uniform(-1, 1, len(x)), 24) * np.exp(-((x - 0.12) ** 2) / 0.012)
tone = np.sin(sweep(720, 230, d, 0.7)) * np.exp(-x * 5) * np.minimum(1, x / 0.02) * 0.5
bump = np.sin(2 * np.pi * 150 * x) * np.exp(-np.maximum(0, x - 0.38) * 40) * (x > 0.38)
save('unbristle', air * 0.9 + tone + bump * 0.4, 0.55)
print("wrote assets/audio/bristle.wav, unbristle.wav")
