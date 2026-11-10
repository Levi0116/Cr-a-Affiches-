# Vidéo « Spécial JBL » – Zeynab Store

Montage vertical 1080 × 1920 (≈ 57 s) fait avec Remotion à partir des vidéos de la boutique :
intro animée, une scène par enceinte (Xtreme 3, Pulse 5, Charge 6, Flip 7) avec fiche technique,
puis l'écran de fin avec les infos de la boutique.

## Ajouter les prix

Dans `src/data.ts`, remplis `price` pour chaque produit (ex. `price: '85.000'`).
La pastille « Prix très bientôt » affichera alors le prix en FCFA.

## Refaire la vidéo

```bash
npm install
npm run render   # crée out/JBL-Zeynab-Store.mp4
npm run studio   # aperçu dans le navigateur
```

`remotion.config.ts` pointe vers le Chromium de l'environnement cloud ; supprime la ligne
`setBrowserExecutable` pour utiliser le Chromium téléchargé par Remotion sur ton ordinateur.
La musique `public/music.m4a` est un rythme généré, libre de droits.
