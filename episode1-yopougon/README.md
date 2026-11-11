# Épisode 1 — « La tenue mousse pas droit » (Yopougon, 01h30)

Court métrage d'animation 2D de **120 secondes** (1920×1080, 30 i/s), réalisé avec [Remotion](https://remotion.dev).
Style webtoon / anime urbain : décors et personnages vectoriels (SVG), cell-shading, contours épais,
lumières néon jaune (dépôt), rouge (maquis) et gyrophare rouge/bleu.

## Contenu

| Scène | Chrono | Plans |
|---|---|---|
| 1. La faune de Yop & le départ de Bravo | 00:00–00:31 | Plan général (kpôclés, client bourré, Jo Le Macho), plan moyen Yao/Bravo, gros plans dialogue, travelling de Bravo vers le poteau |
| 2. L'alerte & l'infiltration du blessé | 00:31–01:00 | Microbes en caméra agitée, silence, caméra épaule sur le blessé, gros plan chuchoté, inserts indices (sac bancaire, montre en or, samaras cassées) |
| 3. La pression & les indices | 01:00–01:40 | Pick-up noir sans plaque + gyrophare muet, flash info à la télé, entrée des faux gonmons, Indice 1 (Jordan neuves), Indice 2 (holster vide) |
| 4. Le choix interactif | 01:40–02:00 | Jeu de regards (gonmon, Bravo, blessé, Yao), arrêt sur image BD fissuré, boutons A / B, voix-off finale |

## Structure

- `src/art/Person.tsx` — personnage paramétrable (pose, expressions, synchro labiale)
- `src/art/cast.ts` — chara-design de chaque personnage (tenues du casting)
- `src/art/Decor.tsx` — rue, dépôt, maquis Chez Chimène, poteau, camion, pick-up
- `src/Scene.tsx` — chorégraphie complète en fonction du temps (une seule « scène monde » filmée par une caméra virtuelle)
- `src/Episode1.tsx` — découpage des plans, sous-titres, mixage audio
- `src/Overlays.tsx` — inserts indices, télé, carton titre, choix A/B
- `src/timeline.ts` — tops des répliques et des effets sonores
- `public/voix`, `public/sfx` — voix (ElevenLabs v3) et bruitages générés

## Commandes

```bash
npm i
npx remotion studio                      # prévisualiser / ajuster
npx remotion render Episode1 out/episode1-yopougon.mp4       # 16:9
npx remotion render Episode1TikTok out/episode1-tiktok.mp4   # 9:16 TikTok
npx remotion render Episode1TikTokV2 out/episode1-tiktok-v2.mp4  # 9:16 version rétention (accroche + compteur d'indices)
# régénérer l'audio (ne réécrit pas les fichiers existants) :
node scripts/generer-audio.mjs && node scripts/lipsync.mjs
```

Note : les voix utilisent des voix ElevenLabs standards (le compte gratuit ne permet pas les voix
de la bibliothèque à accent ivoirien). Pour une version finale, remplacer les fichiers de `public/voix/`
par des enregistrements de comédiens ivoiriens (mêmes noms de fichiers), puis relancer `scripts/lipsync.mjs`.

## Version « rétention » (V2)

`src/EpisodeV2.tsx` remonte le film pour garder l'attention dès la 1re seconde :
accroche en flash-forward (le faux gonmon qui menace, l'œil du blessé, Yao qui hésite) avec le défi
« Trouve les 5 indices avant la fin », rembobinage « 2 minutes plus tôt », passages lents raccourcis,
et badge « 5 indices cachés ». Les indices ne sont jamais montrés : pas de zoom, pas d'étiquette,
la télé « Flash info » reste un détail en arrière-plan (son bas, sans sous-titre). Au spectateur
de repérer les Jordan neuves, le holster vide, le pick-up sans plaque, le gyrophare sans sirène,
le sac de banque et la montre en or.
