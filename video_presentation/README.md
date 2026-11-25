# Vidéo de présentation — Restaurant Chez les Amani

Vidéo animée en motion design (1920 × 1080, 30 images/s, environ 1 min 53) qui présente la plateforme : le problème, le concept, son fonctionnement en 4 étapes, les fonctionnalités, les résultats. Elle met en scène des personnages illustrés (Fatou la serveuse, Koffi le caissier, le patron et des clients) et les vraies captures de l'application.

Réalisée avec [Remotion](https://www.remotion.dev) (React).

## Structure

| Dossier | Contenu |
|---|---|
| `src/theme.ts` | Couleurs du logo, polices, durées des scènes (calées sur la musique), icônes |
| `src/composants/` | Personnages vectoriels animés, appareils (tablette, ordinateur, téléphone, main), décors, sons |
| `src/scenes/` | Les 10 scènes : Intro, Problème, Concept, Serveuse, Caisse, Stock, Patron, Fonctionnalités, Résultats, Outro |
| `src/Presentation.tsx` | Montage complet : scènes, volets de transition, musique |
| `public/ecrans/` | Captures HD de l'application |
| `public/audio/` | Musique et bruitages, synthétisés par `scripts/synthese_audio.py` (libres de droits) |

## Commandes

```bash
npm install
npx remotion studio                                   # aperçu interactif
npx remotion render Presentation out/presentation.mp4 # vidéo finale
npx remotion render Probleme out/probleme.mp4         # une seule scène
```

Sur une machine sans accès à internet, Remotion ne peut pas télécharger son navigateur. `remotion.config.ts` pointe alors vers le Chromium déjà installé : adaptez ce chemin, ou supprimez la ligne sur une machine normale.

## Personnaliser

- **Textes** : directement dans chaque fichier de `src/scenes/`.
- **Couleurs** : `C` dans `src/theme.ts`.
- **Captures** : remplacer les PNG de `public/ecrans/` (mêmes noms).
- **Voix off** : ajouter un fichier `public/audio/voix.mp3` et un `<Audio>` dans `Presentation.tsx` (baisser alors la musique vers 0,35).
