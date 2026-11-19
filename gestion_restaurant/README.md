# Gestion restaurant / maquis

Application de gestion pour restaurant ou maquis, réalisée d'après le cahier des charges du 18/11/2026 : les serveuses prennent les commandes sur tablette, la caisse voit en temps réel ce que chaque table consomme et imprime la facture, et le stock baisse automatiquement à chaque vente.

- **Flutter** (un seul code) : application Android pour les tablettes, application web pour l'ordinateur de la caisse.
- **Cloud Firestore** : données en temps réel, avec copie locale et file d'attente hors ligne.
- **Riverpod** pour l'état de l'application.

## Avancement

Toutes les phases de réalisation du cahier des charges (2 à 10) sont **développées et testées**. Restent les étapes qui demandent le compte et le matériel du client : création des projets Firebase, mise en ligne, test sur la vraie imprimante et les vraies tablettes, recette signée (voir `DEPLOIEMENT.md` et `RECETTE.md`).

| Phase | Contenu | État |
|---|---|---|
| 2 | Projet Flutter Android + Web, organisation `models` / `services` / `features`, Riverpod, Firestore hors ligne | ✅ |
| 3 | Modèles (section 7), PIN haché, déconnexion automatique, **liaison des appareils par QR code**, **élévation administrateur par PIN vérifié côté serveur**, retrait à distance, règles Firestore, journal d'audit | ✅ |
| 4 | Administration : menu, articles, zones et tables, employés, **appareils**, paramètres | ✅ |
| 5 | Plan de salle temps réel, prise de commande, tours, addition, transfert, fusion, annulation, à emporter, indicateur réseau | ✅ |
| 6 | Caisse : tables ouvertes, ticket, facture numérotée, **pavé d'encaissement**, partage, ardoises, duplicata, **ouverture / clôture par comptage des billets** | ✅ |
| 7 | Stock complet : livraisons en casiers, coût moyen, pertes, inventaire validé, fiches techniques, consignes, **alertes de stock (Cloud Function + notification)** | ✅ |
| 8 | Validations (annulations, remises, offerts, ajustements) avec **notification au gérant**, journal d'audit, avoirs | ✅ |
| 9 | Dépenses, tableau de bord, rapports jour / semaine / mois, export Excel et PDF, **rapport du jour pré-calculé à la clôture** | ✅ |
| 10 | Tests : 31 tests Flutter (calculs, soirée simulée, **test de charge 3 tablettes × 100 commandes**, fiches techniques, rapports, Hero, encaissement, comptage) + **14 tests serveur sur l'émulateur Firebase** (règles de sécurité, liaison, élévation, blocage, retrait, déclencheurs) | ✅ |
| 9 (déploiement) | Guide pas à pas, script de création du restaurant, mise à jour proposée dans l'application, sauvegardes quotidiennes, Crashlytics | ✅ (à exécuter chez le client) |

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

## Mise en production avec Firebase

Le guide complet, pas à pas, est dans **`DEPLOIEMENT.md`** : création des projets `resto-dev` et `resto-prod`, `flutterfire configure`, déploiement des règles, des Cloud Functions et de la caisse web, création du restaurant (`npm run creer-restaurant`), liaison des appareils, APK des tablettes, sauvegardes. Sous Windows : **`MISE_EN_SERVICE_WINDOWS.md`** (toutes les commandes PowerShell, liens de téléchargement, dépannage).

En mode Firebase (`--dart-define=FIREBASE=true`), un appareil neuf affiche l'écran **« Lier cet appareil »** : l'administrateur ouvre *Administration → Appareils → Lier un appareil*, un QR code s'affiche (valable 15 minutes, usage unique) ; on le scanne ou on tape les 6 caractères. L'appareil reçoit alors l'accès aux seules données de son restaurant.

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

## Sécurité

- **Liaison des appareils** : Cloud Function `lierAppareil` (code à usage unique), jeton `restaurantId` ; un appareil ne voit que son restaurant.
- **Droits administrateur** : permanents pour le téléphone du gérant (`admin`) ; sur l'ordinateur partagé, l'administrateur qui se connecte reçoit des droits **temporaires de 15 minutes** (`adminJusqua`) après vérification de son PIN **par le serveur**, renouvelés tant qu'il reste connecté. 5 PIN faux bloquent l'appareil 15 minutes. La pastille « Droits administrateur » en haut de l'administration montre l'état.
- **Retrait à distance** : *Administration → Appareils → retirer* ; le compte de l'appareil est désactivé et ses jetons révoqués. Un appareil déjà connecté perd l'accès au plus tard à l'expiration de son jeton (1 heure).
- **Rien n'est supprimé** : règles Firestore testées sur l'émulateur (`functions/test/regles.test.js`).

## Organisation du code

```
lib/
  core/        calculs (totaux, remise, TVA, monnaie, parts, casiers, coût moyen, numéros), fiches techniques, rapports, PIN, formats
  theme/       identité visuelle (identite.dart), thème, motif, animations, icônes de catégories
  models/      modèle de données Firestore (section 7)
  services/    accès Firestore et règles métier : commande, caisse, stock, admin ; appareils (Cloud Functions) ;
               ticket 80 mm ; impression ; export ; données de démo
  state/       providers Riverpod (flux temps réel)
  features/    écrans : connexion, salle, commande, caisse (tables, encaissement, comptage, factures,
               ardoises, journée), stock, admin
  widgets/     éléments communs, indicateur de connexion
test/          calculs + soirée simulée (commande → facture → encaissement → clôture, annulation, partage, ardoise, stock)
functions/     Cloud Functions (TypeScript) + tests sur l'émulateur (règles et fonctions)
firestore.rules, firebase.json, .firebaserc, DEPLOIEMENT.md, RECETTE.md, CHANGELOG.md
```

## Tests

```bash
flutter test                 # 31 tests de l’application
cd functions && npm test     # 14 tests serveur sur l'émulateur Firebase (Java 11+ requis)
```

- **Application :** calculs de facturation, soirée simulée, test de charge (3 serveuses, 100 commandes, facturation et clôture au franc près) sur une base Firestore simulée, fiches techniques, consignes, rapports et export Excel, transition Hero, pavé d'encaissement et comptage de caisse.
- **Serveur :** règles de sécurité (isolement des restaurants, prix réservés à l'administrateur, élévation expirée refusée, factures réglées intouchables, journaux en ajout seul…), liaison des appareils, élévation par PIN, blocage, retrait, alertes de stock, notifications de validation, rapport du jour.
