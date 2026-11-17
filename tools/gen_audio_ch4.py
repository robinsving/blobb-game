"""Synthesises chapter 4's dream music into assets/audio/music_dream.ogg: a slow, airy pad with
no melody and no beat, unresolved chords that drift into each other, and a soft high shimmer.
It loops seamlessly. (The monitor beep on the climb is ch1's beep.wav.)
Usage: python3 tools/gen_audio_ch4.py   (needs numpy; ffmpeg for the .ogg)"""
import numpy as np, wave, subprocess, os
SR = 44100
OUT = 'assets/audio'
rng = np.random.default_rng(4)


def save(name, x, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def lp(x, k=8): return np.convolve(x, np.ones(k) / k, mode='same')


mid = lambda m: 440 * 2 ** ((m - 69) / 12)
CHORD = 12.0                       # seconds per chord, overlapping a lot
prog = [[50, 57, 64, 69], [48, 55, 62, 67], [53, 60, 64, 71], [45, 52, 59, 66]]  # sus/add9 colours
L = CHORD * len(prog)
out = np.zeros(int(SR * (L + CHORD * 1.5)))


def pad(freq, start, dur, amp):
    n = int(SR * dur); x = np.arange(n) / SR
    tone = sum(np.sin(2 * np.pi * freq * (1 + dt) * x + ph) for dt, ph in ((-0.004, 0.0), (0.0, 1.3), (0.005, 2.1)))
    tone *= np.sin(np.pi * x / dur) ** 2          # slow swell in and out
    s = int(SR * start); out[s:s + n] += tone * amp


for i, ch in enumerate(prog):
    t0 = i * CHORD
    pad(mid(ch[0] - 12), t0, CHORD * 1.6, 0.10)
    for m in ch:
        pad(mid(m), t0 + rng.uniform(0, 1.5), CHORD * 1.5, 0.045)
    # a soft shimmer: one high note, very quiet
    pad(mid(ch[-1] + 12), t0 + CHORD * 0.4, CHORD * 0.9, 0.012)

tail = out[int(SR * L):]; out[:len(tail)] += tail; out = out[:int(SR * L)]
out = lp(out, 6)
save('music_dream_tmp', out, 0.5)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f'{OUT}/music_dream_tmp.wav', '-c:a', 'libvorbis', '-q:a', '4', f'{OUT}/music_dream.ogg'], check=True)
os.remove(f'{OUT}/music_dream_tmp.wav')
print('ok')
