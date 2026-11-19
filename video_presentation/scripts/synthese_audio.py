"""Bande sonore originale de la vidéo, entièrement synthétisée (aucun
échantillon externe, donc aucun droit d'auteur tiers) : musique + bruitages.

    python3 scripts/synthese_audio.py   →  public/audio/*.wav
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'public', 'audio')
rng = np.random.default_rng(7)


def ecrire(nom, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    pic = np.max(np.abs(x)) or 1.0
    x = np.clip(x / pic * gain, -1, 1)
    with wave.open(os.path.join(OUT, nom), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())


def t_(d):
    return np.arange(int(d * SR)) / SR


def passe_bas(x, fc):
    """Filtre passe-bas par FFT (pente douce, pas de bourdonnement)."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    X *= 1 / np.sqrt(1 + (f / fc) ** 4)
    return np.fft.irfft(X, n)


def passe_haut(x, fc):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    X *= 1 / np.sqrt(1 + (fc / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(X, n)


def adsr(n, a=0.005, d=0.1, s=0.6, r=0.2, duree_note=None):
    e = np.zeros(n)
    A, D, R = int(a * SR), int(d * SR), int(r * SR)
    N = n if duree_note is None else min(n, int(duree_note * SR))
    e[:A] = np.linspace(0, 1, A, endpoint=False)
    e[A:A + D] = np.linspace(1, s, D, endpoint=False)
    e[A + D:N] = s
    fin = min(n, N + R)
    e[N:fin] = np.linspace(e[N - 1] if N > 0 else s, 0, fin - N)
    return e


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


# ============================================================ MUSIQUE
BPM = 104
TEMPS = 60 / BPM
MESURE = 4 * TEMPS
NB_MESURES = 48
DUREE = NB_MESURES * MESURE + 3.0
N = int(DUREE * SR)
G = np.zeros((N, 2))


def poser(son, debut_s, pan=0.0, vol=1.0):
    i = int(debut_s * SR)
    j = min(N, i + len(son))
    if j <= i:
        return
    g = np.sqrt((1 - pan) / 2) * vol
    d = np.sqrt((1 + pan) / 2) * vol
    G[i:j, 0] += son[: j - i] * g
    G[i:j, 1] += son[: j - i] * d


def marimba(note, d=0.6):
    t = t_(d)
    f = hz(note)
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t * 7)
         + 0.35 * np.sin(2 * np.pi * f * 3.98 * t) * np.exp(-t * 22)
         + 0.12 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 45))
    return s * np.minimum(1, t * 400)


def basse(note, d):
    t = t_(d + 0.1)
    f = hz(note)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)
    return s * adsr(len(t), 0.008, 0.08, 0.7, 0.08, d) * 0.9


def nappe(notes, d):
    t = t_(d + 0.8)
    s = np.zeros(len(t))
    for n_ in notes:
        for desac in (-0.12, 0.0, 0.11):  # léger chorus
            f = hz(n_) * 2 ** (desac / 12)
            ph = rng.uniform(0, 2 * np.pi)
            s += (2 * ((f * t + ph / (2 * np.pi)) % 1) - 1)  # dent de scie
    s = passe_bas(s, 1400)
    return s * adsr(len(t), 0.6, 0.3, 0.8, 0.8, d) / (len(notes) * 3)


def grosse_caisse():
    t = t_(0.45)
    f = 45 + 110 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def shaker(fort=1.0):
    t = t_(0.09)
    return passe_haut(rng.standard_normal(len(t)), 6000) * np.exp(-t * 55) * 0.35 * fort


def rim():
    t = t_(0.12)
    s = passe_haut(rng.standard_normal(len(t)), 1800) * np.exp(-t * 60)
    s += 0.6 * np.sin(2 * np.pi * 820 * t) * np.exp(-t * 70)
    return s * 0.55


def riser(d):
    t = t_(d)
    s = passe_haut(rng.standard_normal(len(t)), 900)
    s = passe_bas(s, 6000)
    return s * (t / d) ** 2.2 * 0.5


# Accords (la mineur) : Am - F - C - G, notes MIDI.
ACCORDS = [([57, 60, 64], 45), ([53, 57, 60], 41), ([48, 52, 55], 36), ([55, 59, 62], 43)]
MOTIF = [0, 2, 4, 2, 7, 4, 2, 4]  # degrés de la gamme pentatonique
PENTA = [57, 60, 62, 64, 67, 69, 72, 74, 76, 79]


def section(m):
    if m < 4:
        return 'intro'
    if m < 11:
        return 'probleme'
    if m < 15:
        return 'concept'
    if m < 39:
        return 'groove'
    if m < 44:
        return 'resultats'
    return 'fin'


for m in range(NB_MESURES):
    t0 = m * MESURE
    sec = section(m)
    notes, racine = ACCORDS[m % 4]
    if sec == 'probleme':  # tension : accords plus sombres
        notes, racine = ([57, 60, 63], 45) if m % 2 == 0 else ([56, 59, 62], 44)
    if sec == 'fin' and m == NB_MESURES - 1:
        notes, racine = [57, 60, 64, 69], 45
    poser(nappe(notes, MESURE), t0, vol=0.55 if sec != 'probleme' else 0.7)
    # Marimba
    if sec in ('intro', 'groove', 'resultats', 'fin', 'concept'):
        for k in range(8):
            if sec == 'intro' and k % 2:
                continue
            deg = MOTIF[(k + m) % len(MOTIF)] + (2 if m % 4 == 3 else 0)
            note = PENTA[min(deg, len(PENTA) - 1)]
            poser(marimba(note), t0 + k * TEMPS / 2, pan=-0.3 if k % 2 else 0.3, vol=0.38)
    elif sec == 'probleme':
        for k in (0, 3, 6):
            poser(marimba(PENTA[k % 3] - 12, 0.5), t0 + k * TEMPS / 2, vol=0.25)
        # tic-tac d'horloge : tension
        for k in range(4):
            poser(rim() * 0.5, t0 + k * TEMPS, pan=0.5 if k % 2 else -0.5, vol=0.5)
    # Rythmique
    if sec in ('groove', 'resultats') or (sec == 'concept' and m >= 13):
        for k in (0, 2, 2.75):
            poser(grosse_caisse(), t0 + k * TEMPS, vol=0.85)
        for k in (1, 3):
            poser(rim(), t0 + k * TEMPS, pan=0.1, vol=0.7)
        for k in range(16):
            poser(shaker(1.0 if k % 2 == 0 else 0.6), t0 + k * TEMPS / 4, pan=0.4, vol=0.6)
        # Basse syncopée
        for (pos, d) in ((0, 0.7), (1.5, 0.35), (2.5, 0.35), (3, 0.6)):
            poser(basse(racine - 12 + (7 if pos == 2.5 else 0), d * TEMPS), t0 + pos * TEMPS, vol=0.9)
    elif sec == 'fin':
        poser(basse(racine - 12, MESURE), t0, vol=0.6)
    if m == 13:  # montée avant le groove
        poser(riser(2 * MESURE), t0, vol=0.6)

# Fondu de sortie + petite réverbération (échos décroissants).
reverb = G.copy()
for k, (dl, a) in enumerate([(0.083, 0.28), (0.131, 0.22), (0.197, 0.15), (0.291, 0.1)]):
    d_ = int(dl * SR)
    reverb[d_:, k % 2] += G[:-d_, (k + 1) % 2] * a
G = reverb
fin = int((NB_MESURES * MESURE + 0.5) * SR)
G[fin:] *= np.linspace(1, 0, N - fin)[:, None]
G[: int(0.6 * SR)] *= np.linspace(0, 1, int(0.6 * SR))[:, None]
ecrire('musique.wav', G, gain=0.8)

# ============================================================ BRUITAGES


def whoosh(d=0.6):
    t = t_(d)
    bruit = rng.standard_normal(len(t))
    bas, haut = passe_bas(bruit, 700), passe_bas(bruit, 4500)
    m = np.sin(np.pi * t / d) ** 2
    return (bas * (1 - t / d) + haut * (t / d)) * m


def pop():
    t = t_(0.18)
    f = 900 * np.exp(-t * 18) + 300
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 25)


def clic():
    t = t_(0.05)
    return (passe_haut(rng.standard_normal(len(t)), 3000) * 0.5 + np.sin(2 * np.pi * 2400 * t)) * np.exp(-t * 140)


def ding(f=1318.5, d=1.6):
    t = t_(d)
    s = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * k)
            for r, a, k in ((1, 1, 3), (2.76, 0.4, 6), (5.4, 0.2, 11), (8.9, 0.08, 18)))
    return s * np.minimum(1, t * 800)


def tampon():
    t = t_(0.5)
    coup = np.sin(2 * np.pi * np.cumsum(60 + 140 * np.exp(-t * 40)) / SR) * np.exp(-t * 14)
    claq = passe_bas(rng.standard_normal(len(t)), 2500) * np.exp(-t * 50) * 0.8
    return coup + claq


def imprimante(d=1.6):
    t = t_(d)
    moteur = np.sign(np.sin(2 * np.pi * 95 * t)) * 0.3 + np.sin(2 * np.pi * 190 * t) * 0.4
    lignes = (np.sin(2 * np.pi * 7 * t) > 0.2).astype(float)
    s = passe_bas(moteur * (0.5 + 0.5 * lignes), 1600) + passe_haut(rng.standard_normal(len(t)), 4000) * 0.08 * lignes
    return s * adsr(len(t), 0.03, 0.05, 1, 0.08, d - 0.08)


def notification():
    return np.concatenate([ding(1046.5, 0.18) * 0.8, ding(1568, 0.9)])


def tiroir_caisse():
    t = t_(1.2)
    pieces = sum(ding(f, 1.2) * np.exp(-((t - dt) ** 2) / 0.0004) for f, dt in ((2637, 0.05), (3136, 0.12), (2349, 0.2)))
    return ding(1760, 1.2) * 0.7 + pieces * 0.5 + passe_haut(rng.standard_normal(len(t)), 5000) * np.exp(-t * 20) * 0.2


def erreur():
    t = t_(0.45)
    return (np.sin(2 * np.pi * 220 * t) + 0.5 * np.sin(2 * np.pi * 233 * t)) * adsr(len(t), 0.01, 0.1, 0.6, 0.15, 0.3)


def papier():
    t = t_(0.5)
    s = passe_haut(rng.standard_normal(len(t)), 2500) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 11 * t)))
    return s * np.sin(np.pi * t / 0.5) ** 2


for nom, son, g in [
    ('whoosh.wav', whoosh(), 0.55), ('whoosh-court.wav', whoosh(0.35), 0.5), ('pop.wav', pop(), 0.6),
    ('clic.wav', clic(), 0.5), ('ding.wav', ding(), 0.55), ('tampon.wav', tampon(), 0.8),
    ('imprimante.wav', imprimante(), 0.45), ('notification.wav', notification(), 0.55),
    ('tiroir-caisse.wav', tiroir_caisse(), 0.6), ('erreur.wav', erreur(), 0.45), ('papier.wav', papier(), 0.4),
]:
    ecrire(nom, son, g)
print('ok', round(DUREE, 1), 's de musique')
