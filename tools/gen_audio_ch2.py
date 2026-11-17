"""Synthesises chapter 2's sounds into assets/audio/: whistle, drip, bubble, turn, flow, gurgle,
and the pool music (music_pool.ogg). Separate from gen_audio.py so ch1's sounds stay unchanged.
Usage: python3 tools/gen_audio_ch2.py   (needs numpy; ffmpeg for the .ogg music)"""
import numpy as np, wave, subprocess, os
SR = 44100
OUT = 'assets/audio'
rng = np.random.default_rng(2)

def t(d): return np.linspace(0, d, int(SR * d), endpoint=False)
def env(n, a=0.005, r=None):
    e = np.ones(n); na = max(1, int(a * SR)); e[:na] = np.linspace(0, 1, na)
    if r: nr = min(n, int(r * SR)); e[-nr:] *= np.linspace(1, 0, nr)
    return e
def save(name, x, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
def sine(f, d): return np.sin(2 * np.pi * np.cumsum(np.broadcast_to(f, (int(SR*d),))) / SR)
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def lp(x, k=8): return np.convolve(x, np.ones(k) / k, mode='same')

# lifeguard whistle: a pea whistle, two short trills
d = 0.7; x = t(d)
f = 2600 + 180 * np.sign(np.sin(2 * np.pi * 34 * x)) + 40 * np.sin(2 * np.pi * 5 * x)
gate = ((x < 0.28) | (x > 0.36)).astype(float)
save('whistle', (sine(f, d) + 0.25 * noise(d)) * env(int(SR*d), 0.01, 0.05) * lp(gate, 400), 0.45)
# drip: a single falling drop into still water
d = 0.35; f = np.linspace(1500, 700, int(SR*d)) ** 1.0
save('drip', sine(f, d) * np.exp(-t(d) * 22) + 0.15 * lp(noise(d), 6) * np.exp(-t(d) * 60), 0.5)
# bubble: a short rising blip
d = 0.12; f = np.linspace(400, 1100, int(SR*d))
save('bubble', sine(f, d) * np.sin(np.pi * t(d) / d) ** 2, 0.5)
# turn: a valve wheel creaks a quarter turn
d = 0.22; save('turn', lp(noise(d), 12) * (0.5 + 0.5 * np.sin(2 * np.pi * 45 * t(d))) * env(int(SR*d), 0.01, 0.08)
               + 0.4 * np.sin(2 * np.pi * 180 * t(d)) * np.exp(-t(d) * 18), 0.6)
# flow: water rushing through pipes
d = 2.0; n = lp(noise(d), 30) * (0.7 + 0.3 * np.sin(2 * np.pi * 3 * t(d)))
save('flow', n * env(int(SR*d), 0.3, 0.6), 0.55)
# gurgle: a pump with something stuck in it
d = 0.9; x = t(d); s = np.zeros_like(x)
for i in range(7):
    st = int(rng.uniform(0, 0.75) * SR); seg = x[:len(x)-st]
    s[st:] += np.sin(2*np.pi*rng.uniform(120, 260)*seg*(1+seg*3)) * np.exp(-seg*30)
save('gurgle', s + 0.2 * lp(noise(d), 80), 0.6)

# music: slow, floaty 6/8 in D, soft sine pads plus a few watery high notes. 16 bars.
bpm = 66; beat = 60 / bpm / 2; bars = 16; L = bars * 6 * beat
out = np.zeros(int(SR * (L + 4)))
def note(freq, start, dur=3.0, amp=0.2, decay=1.4):
    n = int(SR * dur); x = np.arange(n) / SR
    tone = (np.sin(2*np.pi*freq*x) + 0.2*np.sin(2*np.pi*freq*2.0*x)) * np.exp(-x*decay) * np.minimum(1, x * 30)
    s = int(SR * start); out[s:s+n] += tone[:len(out)-s] * amp
mid = lambda m: 440 * 2 ** ((m - 69) / 12)
prog = [[50, 62, 66, 69], [47, 59, 62, 66], [43, 59, 62, 67], [45, 57, 61, 64]]
mel = [78, None, 76, 74, None, None, 76, None, 78, 81, None, None, 79, None, 78, 76, None, None, 74, None, 73, 74, None, None]
for bar in range(bars):
    ch = prog[bar % 4]; t0 = bar * 6 * beat
    note(mid(ch[0]), t0, 5.0, 0.2, 0.6)
    for k, m in enumerate([ch[1], ch[2], ch[3], ch[2], ch[1], ch[2]]):
        note(mid(m), t0 + k * beat, 2.0, 0.07, 2.0)
    if bar >= 2:
        for k in range(6):
            m = mel[(bar * 6 + k) % len(mel)]
            if m: note(mid(m), t0 + k * beat, 3.0, 0.11, 1.0)
tail = out[int(SR*L):]; out[:len(tail)] += tail; out = out[:int(SR*L)]
out = lp(out, 3)
save('music_pool_tmp', out, 0.6)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f'{OUT}/music_pool_tmp.wav', '-c:a', 'libvorbis', '-q:a', '4', f'{OUT}/music_pool.ogg'], check=True)
os.remove(f'{OUT}/music_pool_tmp.wav')
print('ok')
