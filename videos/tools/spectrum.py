# Spectre de la musique, image par image (16 bandes 0..1) -> JSON pour les visuels réactifs.
# Usage : python3 -I tools/spectrum.py public/audio/music.wav src/audio/spectrum.json 30
import sys, wave, json
import numpy as np
src, dst, fps = sys.argv[1], sys.argv[2], int(sys.argv[3])
w = wave.open(src); sr = w.getframerate(); n = w.getnframes()
x = np.frombuffer(w.readframes(n), np.int16).reshape(-1, w.getnchannels()).mean(1) / 32768
win = 2048; han = np.hanning(win)
edges = np.geomspace(40, 12000, 17); freqs = np.fft.rfftfreq(win, 1 / sr)
nf = int(len(x) / sr * fps); out = []; prev = np.zeros(16)
for i in range(nf):
    c = int(i / fps * sr); seg = x[max(0, c - win // 2): c + win // 2]
    if len(seg) < win: seg = np.pad(seg, (0, win - len(seg)))
    mag = np.abs(np.fft.rfft(seg * han))
    b = np.array([mag[(freqs >= edges[k]) & (freqs < edges[k + 1])].mean() for k in range(16)])
    out.append(20 * np.log10(b + 1e-6))
db = np.array(out); lo = np.percentile(db, 20, 0); hi = np.percentile(db, 99.5, 0)
v = np.clip((db - lo) / (hi - lo), 0, 1) ** 1.4; out = []
for r in v:
    prev = np.maximum(r, prev * 0.8); out.append([round(float(t), 2) for t in prev])
json.dump(out, open(dst, 'w'), separators=(',', ':'))
a = np.array(out); print(len(out), a.mean(0).round(2), a.max(0).round(2))
