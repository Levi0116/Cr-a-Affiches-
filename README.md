# Créateur d'affiches Zstore

Outil pour créer les affiches produits de **Zeynab Store** dans le même style que les modèles existants : logo Zstore, accroche, marque et modèle, stockage, prix en FCFA, fiche technique, slogan et pied de page avec contact et magasins.

## Création automatique (IA)

1. Ouvre `index.html` dans Chrome ou Edge.
2. La première fois : ouvre **⚙ Réglages IA**, colle ta clé Gemini, puis clique **Vérifier la clé et choisir les modèles**.
3. Choisis la mise en page **A** ou **B** (rubrique « Démarrer »).
4. Tape la **marque**, le **modèle** et le **prix** (stockage facultatif), puis clique **✨ Créer l'affiche automatiquement**.
   - L'IA cherche sur Internet la fiche technique (écran, mémoire, batterie, caméra ou résistance, Android) et écrit l'accroche, le slogan et les 3 qualités.
   - Elle crée une photo d'un **mannequin différent à chaque fois** (teint, coiffure, visage, corpulence, tenue, bijoux, maquillage, expression, pose tirés au hasard) qui tient le produit et le montre du doigt.
   - Pour le modèle A, elle crée aussi la rangée de coloris, détourée automatiquement.
5. Ça ne te plaît pas ? Clique **👩🏾 Autre mannequin**, ou modifie la description et clique **↻ Refaire la photo**.
6. Vérifie les caractéristiques (l'IA peut se tromper) et corrige-les si besoin dans « Fiche technique ».
7. Clique **⬇ Télécharger l'affiche (PNG)** : image de 2048 × 3072 px.

Astuce : si le téléphone dessiné n'est pas fidèle, ajoute une **photo du produit** dans « Images ». L'IA s'en sert comme modèle.

### Créer ta clé Gemini (5 minutes, gratuit pour commencer)

1. Va sur <https://aistudio.google.com> et connecte-toi avec ton compte Google.
2. Clique **Get API key**, puis **Create API key**.
3. Copie la clé (elle commence par `AIza…`) et colle-la dans **⚙ Réglages IA**.
4. La création d'images peut demander d'activer la facturation sur le projet Google Cloud lié à la clé. Une image coûte environ 25 FCFA selon le modèle.

La clé reste enregistrée uniquement dans ton navigateur. Ne la partage pas.

## Création manuelle

Tu peux aussi tout remplir à la main : clique un exemple (Galaxy A17, Fort 1, Zeno 5, Wave 7C, Shark 6), ajoute ta propre photo et l'image du produit, puis modifie les textes. Dans l'accroche et le modèle, `*mot*` met le mot en rouge.

## Fichiers

- `index.html` : l'éditeur et l'affiche (HTML/CSS/JS).
- `vendor/html-to-image.js` : bibliothèque d'export PNG (licence MIT, voir `vendor/html-to-image.LICENSE`).
