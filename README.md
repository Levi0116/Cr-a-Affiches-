# Créateur d'affiches Zstore

Outil pour créer les affiches produits de **Zeynab Store** dans le même style que les modèles existants : logo Zstore, accroche, marque et modèle, stockage, prix en FCFA, fiche technique, slogan et pied de page avec contact et magasins.

## Utilisation

1. Ouvre `index.html` dans Chrome ou Edge (double-clic suffit, aucune installation).
2. Choisis la mise en page :
   - **A** : prix en haut, 5 atouts avec sous-titres, slogan manuscrit, ruban et logo de la marque en bas (style Galaxy A17 / Fort 1 / Zeno 5).
   - **B** : marque dans une étiquette noire, téléphone au centre, 4 atouts, encadré « PRIX EN FCFA » (style Wave 7C / Shark 6).
3. Clique un exemple (Galaxy A17, Fort 1, Zeno 5, Wave 7C, Shark 6) pour partir d'une affiche déjà remplie.
4. Ajoute la **photo principale** (mannequin + décor, format portrait 2:3 idéalement) et ajuste zoom / décalage.
5. Ajoute l'**image du produit** (PNG sur fond transparent de préférence).
6. Modifie les textes. Astuces : `*mot*` met le mot en rouge (accroche, modèle) ; un retour à la ligne crée une nouvelle ligne.
7. Clique **Télécharger l'affiche (PNG)** : image de 2048 × 3072 px, prête pour WhatsApp, Facebook ou l'impression.

Les champs sont mémorisés dans le navigateur ; les images doivent être rechargées à chaque ouverture.

## Fichiers

- `index.html` : l'éditeur et l'affiche (HTML/CSS/JS).
- `vendor/html-to-image.js` : bibliothèque d'export PNG (licence MIT, voir `vendor/html-to-image.LICENSE`).
