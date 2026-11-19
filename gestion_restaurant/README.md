# Gestion restaurant / maquis

Application de gestion pour restaurant ou maquis, réalisée d'après le cahier des charges du 18/11/2026 : les serveuses prennent les commandes sur tablette, la caisse voit en temps réel ce que chaque table consomme et imprime la facture, et le stock baisse automatiquement à chaque vente.

- **Flutter** (un seul code) : application Android pour les tablettes, application web pour l'ordinateur de la caisse.
- **Cloud Firestore** : données en temps réel, avec copie locale et file d'attente hors ligne.
- **Riverpod** pour l'état de l'application.

## Avancement

Cette première livraison couvre l'**Étape 1 (MVP)** du cahier des charges (phases 2 à 6), plus une partie des étapes 2 et 3.

| Phase | Contenu | État |
|---|---|---|
| 2 | Projet Flutter Android + Web, organisation `models` / `services` / `features`, Riverpod | ✅ |
| 3 | Modèles de données (section 7), connexion par PIN haché, déconnexion automatique, changement d'utilisateur rapide, journal d'audit, règles Firestore | ✅ (liaison des appareils par QR code : à faire) |
| 4 | Administration : catégories, articles (prix, type, unités par casier, seuil, photo), zones et tables, employés (rôle, PIN, désactivation), paramètres | ✅ |
| 5 | Plan de salle temps réel (vert/orange/bleu), commande (catégories, favoris, panier, notes, articles indisponibles grisés, « reste 3 »), validation en écriture groupée, tours horodatés, demande d'addition, transfert, fusion, demande d'annulation, à emporter, indicateur en ligne / hors ligne | ✅ |
| 6 | Caisse : tables ouvertes en temps réel avec détail des tours, alerte « addition demandée », pré-addition, facture finale numérotée FAC-AAAA-NNNNNN, encaissement et monnaie, partage par article ou en parts égales, ardoises, duplicata, ouverture et clôture de caisse, stock des boissons | ✅ |
| 7 | Stock : livraisons en casiers avec coût moyen, pertes, inventaire soumis à validation, portions du jour, disponibilité forcée, historique, **fiches techniques des plats** (déduction des ingrédients, portions possibles), **consignes** (vides à rendre) | ✅ (alertes par notification : à faire) |
| 8 | Validations admin (annulations, remises, offerts, ajustements), journal d'audit filtrable, avoirs AV-AAAA-NNNNNN | ✅ (notification sur le téléphone : à faire) |
| 9 | Tableau de bord du jour, dépenses, **rapports jour / semaine / mois** comparés à la période précédente (CA, panier moyen, marge, bénéfice estimé, ventes par heure, par article et catégorie, serveuses, articles non vendus), **export Excel et PDF** | ✅ (Cloud Function `rapportsJour` : à faire) |
| 10 | Tests automatiques des calculs et d'une soirée simulée | ✅ en partie (tests des règles avec l'émulateur, scénarios hors ligne réels : à faire) |

## Design et identité visuelle

Identité **Restaurant Chez les Amani**, tirée du logo : orange cloche, vert forêt et crème. Le logo détouré (`assets/images/logo_amani.png`) sert aussi d'icône à l'application web et Android.

Deux ambiances, selon le module :
- **sombre « obsidienne verte »** : connexion, plan de salle, prise de commande (moins d'éblouissement le soir, couleurs d'état plus vives) ;
- **claire « crème »** : caisse, stock, administration.

États des tables : émeraude (libre), ambre (occupée), bleu électrique (addition demandée). Ces teintes ont été vérifiées (contraste et daltonisme), et chaque état est aussi écrit en toutes lettres avec une icône : la couleur n'est jamais le seul indice.

Polices : **Plus Jakarta Sans** (titres, montants) et **Inter** (interface), embarquées pour fonctionner hors ligne. Tous les montants, compteurs et heures utilisent des chiffres à chasse fixe (`FontFeature.tabularFigures()`), pour qu'un total qui change ne fasse pas trembler l'écran.

| Fichier | Rôle |
|---|---|
| `lib/theme/identite.dart` | **le seul fichier à modifier** pour une autre charte : couleurs, polices, logo, arrondis, vitesse des animations |
| `lib/theme/app_theme.dart` | thèmes clair et sombre, palette `context.pal`, styles de texte (`AppTypo`), ombres multicouches, dégradé des actions principales, transition entre écrans |
| `lib/theme/animated_widgets.dart` | widgets animés réutilisables (liste ci-dessous) |
| `lib/widgets/animated_table_card.dart` | carte de table animée et fond partagé (Hero) avec l'en-tête de commande |

Widgets animés : `BouncyTapWrapper` (enfoncement à 0,95 et retour élastique, avec vibration légère), `SmoothCounterText` (montant qui compte), `StaggeredEntrance` (cascade de 250 ms sur 15 px), `PulseGlow` et `PulseAlertBadge` (halo et pastille « Addition »), `OfflineStatusPill` (En ligne / Synchronisation / Hors ligne – N en attente), `ShimmerLoading`, `GlassPanel` (verre dépoli), `GradientActionButton`, `QuantityBadge`, `RollingNumber`, `ShakeWrapper`, `showSuccessBurst`, `showStamp`.

Écran par écran :
- **Plan de salle :** les cartes apparaissent en cascade et changent de couleur en 300 ms quand l'état change ; les tables en attente d'addition ont un halo qui respire ; les montants comptent ; une barre flottante en verre dépoli porte les zones et le bouton « À emporter ».
- **Commande :** toucher une table fait s'agrandir sa carte jusqu'à devenir l'en-tête (Hero) ; l'ajout d'un article fait « pop » sa pastille de quantité et glisser le ticket jusqu'à lui.
- **Caisse :** en-tête avec indicateurs en direct (encaissé, en cours, additions à encaisser qui pulsent) et sélecteur de sections à indicateur glissant. La table la plus urgente s'ouvre d'office. Le ticket est présenté comme un reçu (tours, pointillés, total). Les factures s'encaissent sur un **pavé XXL** : billets FCFA qui s'additionnent (5 000 + 2 000), montants rapides, monnaie en grand, clavier physique accepté (chiffres, Entrée, Échap). Ouverture et clôture se font par **comptage des billets et pièces**, avec l'écart en direct (juste / manquant / excédent) et un tampon animé à la clôture.
- **Partout :** le réglage « réduire les animations » de l'appareil est respecté, et les éléments qui bougent en boucle sont isolés (`RepaintBoundary`).

## Essayer tout de suite (mode démonstration)

Sans projet Firebase, l'application démarre avec une base en mémoire déjà remplie (12 tables, un menu de maquis, 5 employés). Les données sont perdues à la fermeture.

```bash
flutter pub get
flutter run -d chrome          # caisse / administration
flutter run -d <tablette>      # application des serveuses
```

| Employé | Rôle | Code PIN |
|---|---|---|
| Awa, Fatou | Serveuse | 1111, 2222 |
| Koffi | Caissier | 3333 |
| Moussa | Gestionnaire de stock | 4444 |
| Patron | Administrateur | 0000 |

> Le mode démonstration s'utilise en mode debug (`flutter run`). En build release, la base en mémoire n'est pas autorisée : on passe alors en mode Firebase.

## Brancher Firebase (phase 2 du cahier des charges)

1. Créer les projets `resto-dev` et `resto-prod`, activer Firestore, Authentication, Hosting, Cloud Messaging et Crashlytics, passer en formule Blaze avec une alerte de budget.
2. `npm install -g firebase-tools` puis `dart pub global activate flutterfire_cli`.
3. `flutterfire configure` : remplace `lib/firebase_options.dart`.
4. Lancer avec la vraie base :

```bash
flutter run -d chrome --dart-define=FIREBASE=true --dart-define=RESTAURANT=<idRestaurant>
```

5. Déployer (section 9) :

```bash
firebase use prod
firebase deploy --only firestore:rules,firestore:indexes
flutter build web --release --no-web-resources-cdn --dart-define=FIREBASE=true --dart-define=RESTAURANT=<id>
firebase deploy --only hosting
flutter build apk --release --dart-define=FIREBASE=true --dart-define=RESTAURANT=<id>
```

`--no-web-resources-cdn` embarque le moteur d'affichage dans l'application : la caisse se recharge même si internet est coupé.

## Impression du ticket (section 4.6)

Le ticket est une page HTML de 80 mm (`@page { size: 80mm auto; }`) imprimée depuis la caisse web. Pour imprimer sans fenêtre de confirmation, installer l'imprimante thermique comme imprimante Windows par défaut et lancer Chrome ainsi :

```
chrome.exe --kiosk-printing --app=https://resto-prod.web.app
```

Pour un PDF à envoyer par WhatsApp, choisir « Enregistrer au format PDF » comme imprimante. Sur la tablette, l'impression n'est pas proposée : c'est la caisse qui imprime.

## Fonctionnement hors ligne

- Toutes les écritures passent par `RestoDb.envoyer` : elles sont appliquées tout de suite dans la copie locale, puis envoyées au serveur au retour de la connexion. L'indicateur en haut de l'écran affiche « En ligne » ou « Hors ligne – N actions en attente ».
- Le stock ne se modifie jamais directement : chaque vente crée un mouvement et un décrément (`FieldValue.increment`), qui s'additionnent sans conflit. Si la dernière bouteille est vendue deux fois hors ligne, le stock devient négatif (signalé « Négatif ! ») au lieu de bloquer le service.
- Chaque document reçoit un identifiant créé sur l'appareil, l'heure de l'appareil (`heureAppareil`) et l'heure serveur (`creeLe`).
- Seule la caisse émet les factures : le compteur est lu dans la copie locale et réécrit dans le même lot que la facture, ce qui garde une suite continue même hors ligne. **Il ne faut donc qu'un seul poste de caisse.**

## Points à trancher pour la phase 3

- **Liaison des appareils par QR code** : une Cloud Function doit créer le compte Firebase de l'appareil avec le jeton `restaurantId`. Les règles (`firestore.rules`) supposent ce jeton.
- **Droits administrateur sur l'ordinateur partagé** : les règles réservent les écritures sensibles au jeton `admin`. Le téléphone du gérant peut le recevoir à la liaison, mais l'ordinateur de la caisse est partagé. Il faudra soit faire valider depuis le téléphone du gérant uniquement, soit une Cloud Function qui vérifie le PIN administrateur et exécute l'action. En attendant, dans l'application, ces actions sont bloquées pour tout employé qui n'a pas le rôle administrateur.
- Les règles n'ont pas encore été testées avec l'émulateur Firebase (phase 10.2).

## Organisation du code

```
lib/
  core/        calculs (totaux, remise, TVA, monnaie, parts, casiers, coût moyen, numéros), fiches techniques, rapports, PIN, formats
  theme/       identité visuelle (identite.dart), thème, motif, animations, icônes de catégories
  models/      modèle de données Firestore (section 7)
  services/    accès Firestore et règles métier : commande, caisse, stock, admin ; ticket 80 mm ; impression ; données de démo
  state/       providers Riverpod (flux temps réel)
  features/    écrans : connexion, salle, commande, caisse (tables, encaissement, comptage, factures,
               ardoises, journée), stock, admin
  widgets/     éléments communs, indicateur de connexion
test/          calculs + soirée simulée (commande → facture → encaissement → clôture, annulation, partage, ardoise, stock)
firestore.rules, firebase.json, .firebaserc
```

## Tests

```bash
flutter test
```

30 tests : calculs de facturation, scénarios complets sur une base Firestore simulée (`fake_cloud_firestore`), fiches techniques, consignes, rapports, export Excel et transition Hero carte de table → en-tête, pavé d'encaissement et comptage de caisse.
