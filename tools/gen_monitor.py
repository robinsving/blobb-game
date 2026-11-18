"""The hospital-monitor beep for ch3's chase, ch4's climb and ch5 (pure Python, no numpy).
Usage:
  python3 tools/gen_monitor.py            # writes build/beeps/: each candidate alone + a tempo demo
  python3 tools/gen_monitor.py B          # installs candidate B as assets/audio/monitor.wav
Candidates:
  A  classic ICU monitor: a clean ~1 kHz tone, soft edges, a little room
  B  pulse oximeter: a short, round "bip" that dies away (what most people know from TV)
  C  warm and low: a softer 740 Hz tone, quieter top, longer tail
  1-5  higher clean monitor tones: 1500, 2000, 2500, 3000, 3500 Hz (short, soft edges)
  F1-F4  flat tones that don't die away (steady, then off), no room:
         F1 1000 Hz pure, F2 440 Hz pure, F3 880 Hz pure, F4 1000 Hz with a small-speaker edge
"""
import math, os, struct, sys, wave

SR = 44100


def tone(freq, dur, attack, hold, harmonics, decay, echo=0.0, glide=0.0):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = freq * (1.0 + glide * math.exp(-t * 60.0))  # tiny pitch drop at the start
        ph += 2 * math.pi * f / SR
        s = math.sin(ph) + sum(a * math.sin(k * ph) for k, a in harmonics)
        if t < attack:
            e = 0.5 - 0.5 * math.cos(math.pi * t / attack)
        elif t < attack + hold:
            e = 1.0
        else:
            e = math.exp(-(t - attack - hold) * decay)
        out.append(s * e)
    if echo:  # a small room: two soft reflections
        for d, g in ((0.031, echo), (0.067, echo * 0.5)):
            k = int(SR * d)
            out += [0.0] * k
            for i in range(len(out) - 1, k - 1, -1):
                out[i] += g * out[i - k] if i - k < n else 0.0
    peak = max(abs(x) for x in out) or 1.0
    fade = int(SR * 0.004)
    for i in range(fade):  # never end on a click
        out[-1 - i] *= i / fade
    return [x / peak * 0.6 for x in out]


CANDIDATES = {
    "A": lambda: tone(1000, 0.26, 0.012, 0.10, [(2, 0.06), (3, 0.03)], 28, echo=0.18),
    "B": lambda: tone(880, 0.20, 0.004, 0.015, [(2, 0.10)], 22, echo=0.12, glide=0.015),
    "C": lambda: tone(740, 0.34, 0.015, 0.07, [(2, 0.04)], 16, echo=0.2),
}
for _k, _f in zip("12345", (1500, 2000, 2500, 3000, 3500)):
    CANDIDATES[_k] = (lambda f: lambda: tone(f, 0.20, 0.006, 0.09, [(2, 0.03)], 35, echo=0.1))(_f)
# steady: 5 ms in, flat for ~150 ms, 8 ms out (decay 600 = gone almost at once)
CANDIDATES["F1"] = lambda: tone(1000, 0.17, 0.005, 0.15, [], 600)
CANDIDATES["F2"] = lambda: tone(440, 0.17, 0.005, 0.15, [], 600)
CANDIDATES["F3"] = lambda: tone(880, 0.17, 0.005, 0.15, [], 600)
CANDIDATES["F4"] = lambda: tone(1000, 0.17, 0.005, 0.15, [(3, 0.18), (5, 0.07)], 600)


def save(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))


def demo(x):
    """Four beeps at 100 bpm, then speeding up to 176 like the end of the chase."""
    out = [0.0] * int(SR * 7.5)
    t, bpm = 0.3, 100.0
    while t < 7.0:
        s = int(t * SR)
        for i, v in enumerate(x):
            if s + i < len(out):
                out[s + i] += v
        t += 60.0 / bpm
        if t > 2.4:
            bpm = min(176.0, bpm + 9.0)
    return out


if __name__ == "__main__":
    if len(sys.argv) > 1:
        save("assets/audio/monitor.wav", CANDIDATES[sys.argv[1].upper()]())
        print("installed", sys.argv[1].upper(), "as assets/audio/monitor.wav")
    else:
        for k, f in CANDIDATES.items():
            x = f()
            save(f"build/beeps/{k}.wav", x)
            save(f"build/beeps/{k}_demo.wav", demo(x))
        old = []
        with wave.open("assets/audio/beep.wav") as w:  # today's sound, for comparison (pitch 1.4)
            raw = w.readframes(w.getnframes())
            v = [s / 32767 for (s,) in struct.iter_unpack("<h", raw)]
            old = [v[int(i * 1.4)] for i in range(int(len(v) / 1.4))]
        save("build/beeps/old_demo.wav", demo(old))
        print("wrote build/beeps/<candidate>{,_demo}.wav and old_demo.wav")
