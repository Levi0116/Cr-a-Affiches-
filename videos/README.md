# Vidéos Zeynab Store (Remotion)

Montages verticaux 1080 × 1920 faits à partir des vidéos de la boutique.

| Vidéo | Composition | Contenu |
|---|---|---|
| Spécial JBL (≈ 57 s) | `JBL` | Xtreme 3, Pulse 5, Charge 6, Flip 7 – `src/data.ts`, `src/Video.tsx` |
| Drones DJI & Xiaomi (≈ 2 min 11) | `DJI` | 9 produits avec prix et voix off – `src/dji-data.ts`, `src/DJIVideo.tsx` |
| La flotte DJI – 3D (≈ 2 min 10) | `DJI3D` | 8 drones : studio 3D (Three.js), photo puis vidéo, HUD, prix – `src/dji2/` |
| Harman Kardon (≈ 1 min 20) | `HK` | Onyx Studio 9 et 8, Aura Studio 2 et 3, prix et voix off – `src/hk-data.ts`, `src/HKVideo.tsx` |

## Modifier les textes et les prix

- JBL : `src/data.ts`, champ `price` (vide = « Prix très bientôt »).
- DJI : `src/dji-data.ts`, champ `price` (vide = « Prix sur demande »), caractéristiques, passages de la vidéo source (`segments`).

## Voix off (DJI et Harman Kardon)

Texte dans `voice-dji.json` / `voice-hk.json`, voix ElevenLabs « aude roxane ». Après avoir changé le texte :

```bash
ELEVENLABS_API_KEY=sk_... python3 make-voice.py voice-dji.json public/dji/voice --force
```

puis refaire le traitement vers `public/dji/vo/` et mettre à jour les durées dans `src/dji-voice.json`
(la durée de chaque scène suit la durée de sa voix).

## Refaire les vidéos

```bash
npm install
npm run render       # out/JBL-Zeynab-Store.mp4
npm run render:dji   # out/DJI-Zeynab-Store.mp4
npm run render:hk    # out/HarmanKardon-Zeynab-Store.mp4
npm run render:dji3d # out/Drones-DJI-3D-Zeynab-Store.mp4 (long : scène 3D WebGL)
npm run studio       # aperçu dans le navigateur
```

`remotion.config.ts` pointe vers le Chromium de l'environnement cloud ; supprime la ligne
`setBrowserExecutable` pour utiliser celui que Remotion télécharge sur ton ordinateur.
Les musiques (`public/music.m4a`, `public/dji/music.m4a`) sont des rythmes générés, libres de droits.

### Voix gratuite (sans ElevenLabs)

La vidéo `DJI3D` utilise la voix française SVOX Pico (gratuite, hors ligne) :

```bash
sudo apt-get install libttspico-utils
bash make-voice-pico.sh voice-dji2-pico.json public/dji2/vo src/dji2-voice.json
```

Les textes ElevenLabs correspondants sont dans `voice-dji2.json` (pour repasser à la voix « aude roxane »).

## Vidéo « Sound Collection » (audio : JBL, Harman Kardon, Bose, Apple)

- Données (produits, prix, caractéristiques, plans vidéo) : `src/audio/data.ts`
- Voix off gratuite : `python3 -I tools/pico-audio.py && bash make-voice-pico.sh voice-audio-pico.json public/audio/vo src/audio-voice.json`
  (texte ElevenLabs prêt dans `voice-audio.json` : `python3 make-voice.py voice-audio.json public/audio/vo --force`, puis recalculer les durées)
- Musique originale : `python3 -I tools/music-audio.py public/audio/music.wav 275`, puis `python3 -I tools/spectrum.py public/audio/music.wav src/audio/spectrum.json 30`
- Photos détourées : `python3 -I tools/cutout2.py photo.jpg public/audio/photos/x.png [all]`
- Rendu : `npm run render:audio` (15 s par produit, ~4 min 20)
