# Restaurant Chez les Amani — plateforme de gestion (version 2)

*Le goût de l'Afrique, la signature AMANI* · Cuisine ivoirienne · Grillades · Boissons

Commandes en salle, caisse, stock et pilotage à distance, pour le **Restaurant Chez les Amani** (+226 65 91 11 76).

## Architecture

| Partie | Technologie | Rôle |
|---|---|---|
| **Application** | Flutter compilé en **PWA** (application web installable) | Une seule application pour les tablettes des serveuses, l'ordinateur de caisse et le téléphone du gérant. S'installe depuis Chrome ou Edge, sur Android et Windows. |
| **Hors ligne** | Copie locale (IndexedDB) + file d'attente + service worker | Tout continue sans internet ; les actions partent au serveur au retour du réseau, sans conflit sur le stock. |
| **Serveur** | **Node.js** (Express) dans `serveur/` | API, vérification des codes, droits par rôle, synchronisation en temps réel, alertes de stock, rapport du jour. |
| **Base de données** | **MySQL 8** | Données du restaurant, appareils liés, sauvegarde quotidienne. |
| **Hébergement** | Un petit VPS Ubuntu (environ 4 à 6 € par mois) | Voir **[MISE_EN_SERVICE.md](MISE_EN_SERVICE.md)** : le guide pas à pas depuis Windows. |

## Fonctionnalités

- **Salle** : plan de salle en direct (libre / occupée / addition), commande en 3 touches, notes, transfert, fusion, vente à emporter.
- **Caisse** :
  - ticket provisoire, facture numérotée sans trou, ticket 80 mm ;
  - encaissement avec monnaie à rendre, partage d'addition, ardoises clients ;
  - ouverture et clôture de caisse avec comptage des billets.
- **Stock** : déduction automatique, livraisons en casiers, fiches techniques des plats, consignes, inventaire, alertes de seuil.
- **Administration** :
  - menu, tables et zones, comptes de l'équipe, appareils, paramètres ;
  - validations (annulations, remises, offerts), avoirs, journal d'audit ;
  - tableau de bord, rapports jour / semaine / mois, export Excel et PDF.

## Comptes et sécurité

- **Seul l'administrateur** crée, modifie ou supprime un compte. Il doit être connecté en ligne : le serveur vérifie son code. Il reste toujours au moins un administrateur actif.
- **Codes personnels** :
  - 6 à 10 chiffres ; les codes trop simples sont refusés ;
  - un code unique par employé ;
  - **blocage 15 min après 5 erreurs** ;
  - jamais stockés en clair (PBKDF2-SHA256 salé, 120 000 itérations).
- **Appareils** : liés par un code à usage unique de 8 caractères (QR code, 15 min) ; retirables à distance. Un appareil retiré efface ses données.
- **Contrôle côté serveur** : chaque écriture est vérifiée. Rien n'est jamais supprimé : une facture réglée ne change plus, on la corrige par un avoir.
- **Serveur** : HTTPS, en-têtes de sécurité (CSP, HSTS), limitation des requêtes, pare-feu, fail2ban, MySQL fermé à internet.

## Démonstration (sans serveur)

```bash
flutter run -d chrome
```

L'application démarre avec un restaurant fictif : 12 tables et un menu ivoirien (garba, kedjenou, foutou sauce graine, placali, alloco, grillades, bissap, gnamakoudji…).

| Employé | Rôle | Code |
|---|---|---|
| Awa | Serveuse | 241197 |
| Fatou | Serveuse | 315208 |
| Koffi | Caissier | 426319 |
| Moussa | Gestionnaire de stock | 537420 |
| Patron | Administrateur | 482615 |

## Construire la PWA de production

```bash
flutter build web --release --no-web-resources-cdn --dart-define=SERVEUR=true
node outils/generer-sw.mjs       # copie hors ligne de l'application (service worker)
```

Le serveur (`serveur/`) sert ce dossier `build/web` et l'API sous `/api`.

## Tests

```bash
flutter test                                        # 32 tests de l'application
cd serveur && npm install && npm test               # tests du serveur (MySQL requis)
AMANI_TEST_SERVEUR=1 flutter test test/synchro_test.dart   # hors ligne de bout en bout avec le vrai serveur
```

Ce qui est testé :

- **Application** : calculs de facturation, soirée simulée, charge de 3 tablettes × 100 commandes, fiches techniques, rapports, encaissement, comptage, codes PIN (empreinte identique à celle du serveur).
- **Serveur** :
  - liaison des appareils, connexion et blocage ;
  - comptes réservés à l'administrateur ;
  - droits d'écriture, incréments sans conflit, lots appliqués une seule fois ;
  - factures et journées verrouillées, alertes, temps réel, retrait d'un appareil.
- **Intégration** : coupure de réseau, ventes simultanées, redémarrage avec une file d'attente pleine, écriture refusée.

## Organisation du code

```
lib/
  donnees/     base locale hors ligne, synchronisation, client de l'API
  core/        calculs, rapports, codes PIN (PBKDF2)
  models/      modèle de données
  services/    règles métier : commande, caisse, stock, admin ; comptes et appareils
  features/    écrans : liaison, connexion, salle, commande, caisse, stock, administration
  theme/       identité « Signature Amani » (couleurs, polices, motif Kita, animations)
serveur/
  src/         API Express, règles d'écriture, synchronisation, alertes
  scripts/     creer-restaurant, code-liaison, migrer
  deploiement/ installation du VPS, Nginx, sauvegarde, démarrage
outils/        generer-sw.mjs (service worker de la PWA)
web/           manifeste, icônes, page d'accueil de la PWA
```

Documents : **[MISE_EN_SERVICE.md](MISE_EN_SERVICE.md)** (test local puis hébergement), **[HEBERGEMENT_LWS.md](HEBERGEMENT_LWS.md)** (hébergement chez LWS), **[RECETTE.md](RECETTE.md)** (procès-verbal de recette), **[CHANGELOG.md](CHANGELOG.md)**.
