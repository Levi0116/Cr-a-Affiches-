# Guide de déploiement — Restaurant Chez les Amani

Ce guide met en service la version de production : le serveur en ligne (Firebase), l'application de caisse (web) et l'application des tablettes (Android). Il suit la section 9 du cahier des charges.

> 🪟 **Sous Windows**, suivez plutôt le guide pas à pas détaillé, avec toutes les commandes PowerShell : [MISE_EN_SERVICE_WINDOWS.md](MISE_EN_SERVICE_WINDOWS.md).

> **Toujours vérifier le projet actif** avant de déployer : `firebase use` affiche `resto-dev` ou `resto-prod`.

---

## 1. Outils (une seule fois)

| Outil | Installation |
|---|---|
| Flutter (stable) | <https://docs.flutter.dev/get-started/install> |
| Node.js 22 | <https://nodejs.org> |
| Java 11 ou plus (émulateur, pour les tests) | <https://adoptium.net> |
| Firebase CLI | `npm install -g firebase-tools` puis `firebase login` |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` |
| Android Studio (pour l'APK) | <https://developer.android.com/studio> |

---

## 2. Créer les deux projets Firebase

Dans la [console Firebase](https://console.firebase.google.com) :

1. Créer **`resto-dev`** (tests) et **`resto-prod`** (vraies données). On ne teste jamais sur la production.
2. Pour **chacun** :
   - **Firestore** : créer la base en mode production. Emplacement : `europe-west1` (ou celui choisi pour tout le projet ; il doit correspondre à `REGION` dans `functions/src/commun.ts`).
   - **Authentication** → Méthodes de connexion → activer **Anonyme** (les appareils se connectent ainsi avant d'être liés).
   - **Hosting**, **Cloud Messaging**, **Crashlytics** : activer.
   - **Formule Blaze** (Cloud Functions et sauvegardes). Créer tout de suite une **alerte de budget** dans Google Cloud → Facturation → Budgets (par exemple 5 000 F par mois).
3. Dans `.firebaserc`, vérifier les identifiants exacts des projets (`dev` → `resto-dev`, `prod` → `resto-prod`).

---

## 3. Relier l'application aux projets

```bash
cd gestion_restaurant
flutterfire configure --project=resto-prod --platforms=android,web
```

Cela remplace `lib/firebase_options.dart` et ajoute `android/app/google-services.json`.

---

## 4. Tester sur l'émulateur avant tout déploiement

```bash
cd functions
npm install
npm test          # 14 tests : règles de sécurité + Cloud Functions
cd ..
flutter test      # 31 tests de l’application
```

Tout doit être vert.

---

## 5. Déployer le serveur

```bash
firebase use prod
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

Dans la console Firebase → Functions, vérifier que les fonctions sont actives : `lierAppareil`, `creerCodeLiaison`, `elevationAdmin`, `finElevationAdmin`, `revoquerAppareil`, `surveillerStock`, `notifierDemande`, `rapportJour`, `sauvegardeQuotidienne`.

### Sauvegardes quotidiennes (section 9.6)

```bash
gsutil mb -l europe-west1 gs://resto-prod-sauvegardes
# Conserver 14 jours :
echo '{"rule":[{"action":{"type":"Delete"},"condition":{"age":14}}]}' > cycle.json
gsutil lifecycle set cycle.json gs://resto-prod-sauvegardes
```

Donner au compte de service des Cloud Functions (`NUMERO_PROJET-compute@developer.gserviceaccount.com`) le rôle **Cloud Datastore Import Export Admin** et l'accès au bucket (commandes exactes : guide Windows, § 7). La fonction `sauvegardeQuotidienne` exporte la base chaque jour à 4 h (heure de Ouagadougou).

---

## 6. Créer le restaurant et le premier administrateur

Avec une clé de compte de service (console → Paramètres du projet → Comptes de service → Générer une clé ; **ne jamais la mettre dans Git**) :

```bash
cd functions
GOOGLE_APPLICATION_CREDENTIALS=~/cles/resto-prod.json \
npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" \
  --telephone "+226 65 91 11 76" --admin "Patron" --pin 4826
```

Le script affiche un **code de liaison** (15 minutes) pour le premier appareil : le téléphone du gérant, qui reçoit les droits administrateur permanents.

---

## 7. Mettre en ligne la caisse (web)

```bash
flutter build web --release --no-web-resources-cdn --dart-define=FIREBASE=true
firebase deploy --only hosting
```

- Adresse : `https://resto-prod.web.app` (un domaine personnalisé comme `caisse.monappli.bf` s'ajoute dans Hosting).
- `--no-web-resources-cdn` embarque le moteur d'affichage : la caisse se recharge même sans internet.
- Retour en arrière : console → Hosting → historique des versions → *Restaurer*.

### Ordinateur de la caisse

1. Installer l'imprimante thermique 80 mm comme **imprimante Windows par défaut**.
2. Créer un raccourci Chrome :
   `chrome.exe --kiosk-printing --app=https://resto-prod.web.app`
   Le ticket s'imprime alors directement, sans fenêtre de confirmation.
3. Ouvrir l'application, scanner ou taper le code de liaison créé depuis le téléphone du gérant (*Administration → Appareils → Lier un appareil*, type « Caisse »).

---

## 8. Application des tablettes (Android)

### Clé de signature (une seule fois — à conserver précieusement, en plusieurs copies)

```bash
keytool -genkey -v -keystore ~/cles/amani-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias amani
```

Créer `android/key.properties` (jamais dans Git) :

```
storePassword=…
keyPassword=…
keyAlias=amani
storeFile=/chemin/vers/amani-release.jks
```

`android/app/build.gradle.kts` lit ce fichier automatiquement (sans lui, la version release est signée avec la clé de débogage). Sans cette clé, aucune mise à jour de l'application ne sera possible.

### Construire et installer

```bash
flutter build apk --release --dart-define=FIREBASE=true
```

Copier `build/app/outputs/flutter-apk/app-release.apk` sur chaque tablette (câble USB ou lien de téléchargement), autoriser l'installation depuis cette source, puis lier la tablette avec un code « Tablette ».

### Mises à jour sans Google Play

Publier l'APK à une adresse de téléchargement, puis dans Firestore (console) créer ou modifier le document `config/version` :

```json
{ "derniere": "1.1.0", "minimale": "1.0.0", "urlApk": "https://…/app-release.apk", "notes": "Rapports plus rapides" }
```

Les tablettes et la caisse affichent alors « Nouvelle version disponible » (rechargement en un clic sur la caisse, téléchargement de l'APK sur tablette). Avec `minimale` supérieure à la version installée, le bandeau devient rouge (mise à jour obligatoire).

Plus tard, pour plusieurs clients : Google Play (25 $ une fois ; un compte récent doit d'abord faire un **test fermé de 14 jours avec au moins 12 testeurs**).

---

## 9. Procédure de mise à jour en production (section 9.5)

1. Tester la nouvelle version sur `resto-dev` (`firebase use dev`, mêmes commandes).
2. Déployer **le matin, hors service**.
3. Vérifier une commande test et une impression.
4. En cas de problème : Hosting → restaurer la version précédente ; tablettes → réinstaller l'APK précédent.
5. Prévenir le gérant des nouveautés (WhatsApp) et mettre à jour `CHANGELOG.md`.

---

## 10. Surveillance

- **Crashlytics** : plantages des tablettes, avec la pile d'appels.
- **Console Firebase → Utilisation** : lectures et écritures Firestore.
- **Alerte de budget** sur le compte de facturation Google.
- **Export mensuel** remis au client : *Administration → Rapports → Mois → Excel*.
