# Vidéos Zeynab Store (Remotion)

Montages verticaux 1080 × 1920 faits à partir des vidéos de la boutique.

| Vidéo | Composition | Contenu |
|---|---|---|
| Spécial JBL (≈ 57 s) | `JBL` | Xtreme 3, Pulse 5, Charge 6, Flip 7 – `src/data.ts`, `src/Video.tsx` |
| Drones DJI & Xiaomi (≈ 2 min 11) | `DJI` | 9 produits avec prix et voix off – `src/dji-data.ts`, `src/DJIVideo.tsx` |

## Modifier les textes et les prix

- JBL : `src/data.ts`, champ `price` (vide = « Prix très bientôt »).
- DJI : `src/dji-data.ts`, champ `price` (vide = « Prix sur demande »), caractéristiques, passages de la vidéo source (`segments`).

## Voix off (DJI)

Texte dans `voice-dji.json`, voix ElevenLabs « aude roxane ». Après avoir changé le texte :

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
npm run studio       # aperçu dans le navigateur
```

`remotion.config.ts` pointe vers le Chromium de l'environnement cloud ; supprime la ligne
`setBrowserExecutable` pour utiliser celui que Remotion télécharge sur ton ordinateur.
Les musiques (`public/music.m4a`, `public/dji/music.m4a`) sont des rythmes générés, libres de droits.
