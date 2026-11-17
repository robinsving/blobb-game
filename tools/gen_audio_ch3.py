"""Synthesises chapter 3's sounds into assets/audio/: kick and hat (the chase beat; the monitor
beep is ch1's beep.wav), crank, lamp_on, coo, flap, and the night-town music (music_city.ogg).
Usage: python3 tools/gen_audio_ch3.py   (needs numpy; ffmpeg for the .ogg music)"""
import numpy as np, wave, subprocess, os
SR = 44100
OUT = 'assets/audio'
rng = np.random.default_rng(3)

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
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def lp(x, k=8): return np.convolve(x, np.ones(k) / k, mode='same')
def hp(x, k=8): return x - lp(x, k)

# kick: a soft round drum, pitch dropping fast
d = 0.35; x = t(d); f = 45 + 110 * np.exp(-x * 30)
save('kick', np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 9) * env(len(x), 0.002), 0.9)
# hat: a short closed hi-hat
d = 0.06; save('hat', hp(noise(d), 3) * np.exp(-t(d) * 70), 0.35)
# crank: an iron ratchet, four clicks
d = 0.3; s = np.zeros(int(SR * d))
for i in range(4):
    st = int(i * 0.065 * SR); n = int(0.03 * SR)
    s[st:st + n] += hp(noise(0.03), 2) * np.exp(-np.arange(n) / SR * 160) + 0.5 * np.sin(2 * np.pi * 900 * np.arange(n) / SR) * np.exp(-np.arange(n) / SR * 120)
save('crank', s, 0.55)
# lamp_on: a glassy tink and a soft electric hum swelling in
d = 0.9; x = t(d)
tink = np.sin(2 * np.pi * 2350 * x) * np.exp(-x * 14) + 0.5 * np.sin(2 * np.pi * 3520 * x) * np.exp(-x * 20)
hum = (np.sin(2 * np.pi * 100 * x) + 0.4 * np.sin(2 * np.pi * 200 * x)) * np.minimum(1, x * 3) * np.exp(-x * 2)
save('lamp_on', tink * 0.6 + hum * 0.25, 0.5)
# coo: a pigeon's sleepy two-note coo
d = 0.8; x = t(d); f = np.where(x < 0.35, 420 - 60 * x, 380 - 90 * (x - 0.35))
am = np.sin(np.pi * np.clip(x / 0.35, 0, 1)) * (x < 0.35) + np.sin(np.pi * np.clip((x - 0.42) / 0.38, 0, 1)) * (x >= 0.42)
save('coo', np.sin(2 * np.pi * np.cumsum(f) / SR) * am * (1 + 0.3 * np.sin(2 * np.pi * 28 * x)), 0.5)
# flap: wings taking off, a few soft whumps of noise
d = 0.7; s = np.zeros(int(SR * d))
for i in range(6):
    st = int(i * 0.1 * SR); n = int(0.08 * SR)
    s[st:st + n] += lp(noise(0.08), 20) * np.sin(np.pi * np.arange(n) / n) ** 2 * (1 - i * 0.12)
save('flap', s, 0.6)

# music: night town. Slow 4/4 in A minor, soft electric piano and a warm pad, no drums
# (the chase brings its own beat). 16 bars, loops.
bpm = 72; beat = 60 / bpm; bars = 16; L = bars * 4 * beat
out = np.zeros(int(SR * (L + 5)))
def note(freq, start, dur=3.0, amp=0.2, decay=1.4, bright=0.25):
    n = int(SR * dur); x = np.arange(n) / SR
    tone = (np.sin(2*np.pi*freq*x) + bright*np.sin(2*np.pi*freq*2.0*x) + 0.08*np.sin(2*np.pi*freq*3.0*x)) * np.exp(-x*decay) * np.minimum(1, x * 40)
    s = int(SR * start); out[s:s+n] += tone[:len(out)-s] * amp
def pad(freq, start, dur, amp=0.05):
    n = int(SR * dur); x = np.arange(n) / SR
    tone = sum(np.sin(2*np.pi*freq*(1 + dt)*x) for dt in (-0.003, 0, 0.004)) * np.sin(np.pi * x / dur) ** 1.5
    s = int(SR * start); out[s:s+n] += tone[:len(out)-s] * amp
mid = lambda m: 440 * 2 ** ((m - 69) / 12)
prog = [[45, 57, 60, 64], [41, 57, 60, 65], [48, 55, 60, 64], [43, 55, 59, 62]]
mel = [76, None, 74, 72, None, 72, 74, None, 76, None, 79, None, 77, None, 76, 74]
for bar in range(bars):
    ch = prog[bar % 4]; t0 = bar * 4 * beat
    note(mid(ch[0]), t0, 6.0, 0.18, 0.5)
    for m in ch[1:]:
        pad(mid(m), t0, 4 * beat + 0.6)
    for k, m in enumerate([ch[1], ch[2], ch[3], ch[2]]):
        note(mid(m), t0 + k * beat + 0.5 * beat, 2.0, 0.05, 2.2)
    if bar >= 4:
        for k in range(4):
            m = mel[(bar * 4 + k) % len(mel)]
            if m: note(mid(m), t0 + k * beat, 3.0, 0.09, 1.1, 0.4)
tail = out[int(SR*L):]; out[:len(tail)] += tail; out = out[:int(SR*L)]
out = lp(out, 3)
save('music_city_tmp', out, 0.6)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f'{OUT}/music_city_tmp.wav', '-c:a', 'libvorbis', '-q:a', '4', f'{OUT}/music_city.ogg'], check=True)
os.remove(f'{OUT}/music_city_tmp.wav')
print('ok')
