# Musique originale libre de droits (house/afro-pop, 112 BPM) pour la vidéo Audio.
# Usage : python3 -I tools/music-audio.py public/audio/music.wav 200
import sys, wave
import numpy as np
out, dur = sys.argv[1], float(sys.argv[2])
SR = 44100; BPM = 112; beat = 60 / BPM; N = int(dur * SR)
L = np.zeros(N); R = np.zeros(N)
rng = np.random.default_rng(7)
def add(sig, t, pan=0.0, g=1.0):
    i = int(t * SR); n = min(len(sig), N - i)
    if n <= 0: return
    L[i:i+n] += sig[:n] * g * (1 - max(pan, 0)); R[i:i+n] += sig[:n] * g * (1 + min(pan, 0))
def env(n, a=0.002, d=0.2):
    t = np.arange(n) / SR; e = np.minimum(t / a, 1) * np.exp(-t / d); return e
def kick():
    n = int(0.45 * SR); t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t * 28); ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7) * 1.0 + rng.normal(0, 1, n) * np.exp(-t * 300) * 0.15
def clap():
    n = int(0.3 * SR); t = np.arange(n) / SR; nz = rng.normal(0, 1, n)
    e = sum(np.exp(-np.maximum(t - k * 0.011, 0) * 60) * (t >= k * 0.011) for k in range(3)) * 0.5 + np.exp(-t * 18) * 0.6
    b = np.convolve(nz, np.ones(4) / 4, 'same') - np.convolve(nz, np.ones(40) / 40, 'same')
    return b * e * 0.55
def hat(open_=False):
    n = int((0.25 if open_ else 0.05) * SR); t = np.arange(n) / SR; nz = rng.normal(0, 1, n)
    nz = nz - np.convolve(nz, np.ones(6) / 6, 'same')
    return nz * np.exp(-t * (14 if open_ else 70)) * 0.22
def tone(freq, length, kind='saw', d=0.4, cutoff=1.0):
    n = int(length * SR); t = np.arange(n) / SR
    if kind == 'sine': s = np.sin(2 * np.pi * freq * t)
    else:
        s = sum(np.sin(2 * np.pi * freq * k * t) / k * (cutoff ** (k - 1)) for k in range(1, 14))
    return s * env(n, 0.005, d)
def midi(m): return 440 * 2 ** ((m - 69) / 12)
prog = [(57, [57, 60, 64]), (53, [53, 57, 60]), (48, [55, 60, 64]), (55, [55, 59, 62])]  # Am F C G
bar = 4 * beat; bars = int(dur / bar) + 1
side = np.ones(N)
for b in range(bars):
    t0 = b * bar
    if t0 > dur: break
    root, chord = prog[b % 4]
    intro = b < 2 or b % 32 in (30, 31)
    for k in range(4):
        tb = t0 + k * beat
        if not intro:
            add(kick(), tb, g=0.9)
            i = int(tb * SR); n = min(int(0.25 * SR), N - i)
            if n > 0: side[i:i+n] = np.minimum(side[i:i+n], 0.35 + 0.65 * (np.arange(n) / n) ** 0.6)
        if k in (1, 3) and not intro: add(clap(), tb, g=0.8)
        for s in range(4):
            ts = tb + s * beat / 4 + (0.018 if s % 2 else 0)
            if s == 2: add(hat(b % 2 == 1 and k == 3), ts, pan=0.3, g=0.9)
            elif not intro: add(hat(), ts, pan=-0.25, g=0.5 + 0.3 * (s == 1))
    # basse syncopée
    if not intro:
        for pos, m in [(0, 0), (0.75, 0), (1.5, 12), (2.5, 0), (3.25, 7), (3.5, 0)]:
            add(tone(midi(root - 24), beat * 0.6, 'saw', 0.18, 0.45) * 0.38 + tone(midi(root - 24), beat * 0.6, 'sine', 0.25) * 0.45, t0 + pos * beat)
    # pad (accord) étiré
    pad = sum(tone(midi(m), bar, 'saw', 3.0, 0.35) for m in chord) * 0.06
    pad *= np.minimum(np.arange(len(pad)) / (0.3 * SR), 1)
    add(pad, t0, pan=-0.4); add(pad, t0 + 0.012, pan=0.4)
    # arpège pluck
    if b >= 4:
        arp = chord + [chord[0] + 12, chord[1] + 12]
        for s in range(16):
            if s % 3 == 2 and b % 2: continue
            m = arp[(s * 2 + b) % len(arp)] + 12
            add(tone(midi(m), beat / 2, 'saw', 0.09, 0.5) * 0.09, t0 + s * beat / 4, pan=0.5 if s % 2 else -0.5)
mixL = L.copy(); mixR = R.copy()
# écho stéréo léger
d = int(beat * 0.75 * SR)
mixL[d:] += R[:-d] * 0.18; mixR[d:] += L[:-d] * 0.18
mixL *= side ** 0.5; mixR *= side ** 0.5
fade = int(3 * SR); mixL[-fade:] *= np.linspace(1, 0, fade); mixR[-fade:] *= np.linspace(1, 0, fade)
st = np.stack([mixL, mixR], 1); st = np.tanh(st / np.abs(st).max() * 1.6) * 0.9
with wave.open(out, 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st * 32767).astype(np.int16).tobytes())
print(out)
