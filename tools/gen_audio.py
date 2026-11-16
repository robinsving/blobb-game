"""Synthesises Blobb's placeholder sound effects and music into assets/audio/.
Usage: python3 tools/gen_audio.py   (needs numpy; ffmpeg for the .ogg music)"""
import numpy as np, wave, subprocess, os
SR = 44100
OUT = 'assets/audio'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1)

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
def lp(x, k=8):  # cheap low-pass
    return np.convolve(x, np.ones(k) / k, mode='same')

# typing blips
x = t(0.05); save('blip_old', np.sin(2*np.pi*330*x) * np.exp(-x*60), 0.5)
x = t(0.05); save('blip_young', np.sin(2*np.pi*620*x) * np.exp(-x*70), 0.5)
# pop (appear)
d = 0.18; f = np.linspace(300, 900, int(SR*d)); save('pop', sine(f, d) * np.exp(-t(d)*18))
# push: wooden scrape
d = 0.16; save('push', lp(noise(d), 30) * np.exp(-t(d)*14) + 0.4*np.sin(2*np.pi*90*t(d))*np.exp(-t(d)*25))
# splash
d = 0.7; n = lp(noise(d), 4) * np.exp(-t(d)*5); bub = sum(np.sin(2*np.pi*(500+i*170)*t(d)) * np.exp(-((t(d)-0.08*i-0.05)**2)/0.0004) for i in range(5)); save('splash', n + 0.3*bub)
# plate click
d = 0.2; save('plate', np.sin(2*np.pi*1200*t(d))*np.exp(-t(d)*50) + 0.6*np.sin(2*np.pi*600*t(d))*np.exp(-t(d)*30))
# gate: wooden creak + thunk
d = 0.6; f = 140 + 40*np.sin(2*np.pi*7*t(d)); save('gate', sine(f, d)*env(int(SR*d), 0.02, 0.2)*0.6 + lp(noise(d), 40)*np.exp(-t(d)*6))
# rewind: reverse sweep warble
d = 0.9; f = np.linspace(900, 200, int(SR*d)) * (1 + 0.05*np.sin(2*np.pi*12*t(d))); save('rewind', sine(f, d) * env(int(SR*d), 0.05, 0.3), 0.5)
# whoosh
d = 1.4; nz = noise(d); s = np.zeros_like(nz)
for k, a in enumerate(np.linspace(2, 60, 6)): s += lp(nz, int(a))
save('whoosh', s * np.sin(np.pi * t(d) / d) ** 2, 0.6)
# hospital monitor beep
d = 0.22; save('beep', np.sin(2*np.pi*988*t(d)) * env(int(SR*d), 0.004, 0.03), 0.6)
# shrink: falling slide whistle
d = 0.6; f = np.linspace(1200, 300, int(SR*d)); save('shrink', sine(f, d) * env(int(SR*d), 0.01, 0.1), 0.6)
# rumble
d = 1.0; save('rumble', lp(noise(d), 200) * env(int(SR*d), 0.05, 0.5) + 0.5*np.sin(2*np.pi*45*t(d))*env(int(SR*d), 0.05, 0.5))
# bonk
d = 0.25; f = np.linspace(400, 150, int(SR*d)); save('bonk', sine(f, d) * np.exp(-t(d)*14))
# land: soft thud
d = 0.12; save('land', lp(noise(d), 60) * np.exp(-t(d)*35))
# grow: rising rustle + chirp
d = 1.0; f = np.linspace(200, 700, int(SR*d)); save('grow', sine(f, d)*0.4*env(int(SR*d), 0.02, 0.3) + lp(noise(d), 6)*0.3*env(int(SR*d), 0.2, 0.4), 0.6)
# chime: magic bell arpeggio
d = 1.4; x = t(d); s = np.zeros_like(x)
for i, fr in enumerate([784, 988, 1175, 1568]):
    st = int(i * 0.09 * SR); seg = x[:len(x)-st]
    s[st:] += np.sin(2*np.pi*fr*seg) * np.exp(-seg*4) * (1 + 0.3*np.sin(2*np.pi*fr*2.01*seg))
save('chime', s, 0.5)

# music: gentle music box waltz, 3/4 at 84 bpm, C - Am - F - G, 16 bars
bpm = 84; beat = 60 / bpm; bars = 16; L = bars * 3 * beat
out = np.zeros(int(SR * (L + 3)))
def note(freq, start, dur=2.5, amp=0.25):
    n = int(SR * dur); x = np.arange(n) / SR
    tone = (np.sin(2*np.pi*freq*x) + 0.35*np.sin(2*np.pi*freq*2*x) + 0.12*np.sin(2*np.pi*freq*3.01*x)) * np.exp(-x*2.6)
    s = int(SR * start); out[s:s+n] += tone[:len(out)-s] * amp
mid = lambda m: 440 * 2 ** ((m - 69) / 12)
prog = [[48, 60, 64, 67], [45, 57, 60, 64], [41, 57, 60, 65], [43, 55, 59, 62]]
melody = [76, 74, 72, 74, 76, 76, 76, None, 74, 74, 74, None, 76, 79, 79, None,
          76, 74, 72, 74, 76, 76, 76, 76, 74, 74, 76, 74, 72, None, None, None]
for bar in range(bars):
    ch = prog[bar % 4]; t0 = bar * 3 * beat
    note(mid(ch[0]), t0, 3.0, 0.22)
    for k in range(1, 3): note(mid(ch[1 + (k % 3)]), t0 + k * beat, 1.5, 0.1); note(mid(ch[2]), t0 + k * beat, 1.5, 0.08)
    for k in range(3):
        m = melody[(bar * 3 + k) % len(melody) * 1 % len(melody)] if bar >= 4 else None
        if m: note(mid(m), t0 + k * beat, 2.0, 0.16)
# loop tail wrap
tail = out[int(SR*L):]; out[:len(tail)] += tail; out = out[:int(SR*L)]
save('music_forest_tmp', out, 0.6)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f'{OUT}/music_forest_tmp.wav', '-c:a', 'libvorbis', '-q:a', '4', f'{OUT}/music_forest.ogg'], check=True)
os.remove(f'{OUT}/music_forest_tmp.wav')
print('ok')
