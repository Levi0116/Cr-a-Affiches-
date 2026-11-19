# Mise en service réelle — guide pas à pas sous Windows

**Restaurant Chez les Amani · version 1.0.0**

Ce guide part d'un ordinateur Windows 10 ou 11 vierge et va jusqu'au premier service réel. Chaque commande est à **copier-coller telle quelle** dans **PowerShell**. Comptez une journée pour tout faire, plus le temps de saisir le menu.

> **Légende**
> 🖱️ action à la souris dans un site ou une application · ⌨️ commande PowerShell · ⚠️ point important · ✅ ce que vous devez voir

---

## Sommaire

0. [Ce qu'il faut avant de commencer](#0-ce-quil-faut-avant-de-commencer)
1. [Installer les outils sur l'ordinateur de travail](#1-installer-les-outils-sur-lordinateur-de-travail)
2. [Récupérer le code de la plateforme](#2-récupérer-le-code-de-la-plateforme)
3. [Vérifier que tout fonctionne (tests)](#3-vérifier-que-tout-fonctionne-tests)
4. [Créer les projets Firebase](#4-créer-les-projets-firebase-serveur-en-ligne)
5. [Relier le code aux projets](#5-relier-le-code-aux-projets)
6. [Déployer le serveur](#6-déployer-le-serveur-règles--fonctions)
7. [Activer les sauvegardes quotidiennes](#7-activer-les-sauvegardes-quotidiennes)
8. [Construire l'application Android (APK)](#8-construire-lapplication-android-apk)
9. [Mettre en ligne la caisse (web)](#9-mettre-en-ligne-la-caisse-web)
10. [Créer le restaurant et lier le téléphone du gérant](#10-créer-le-restaurant-et-lier-le-téléphone-du-gérant)
11. [Préparer l'ordinateur de caisse et l'imprimante](#11-préparer-lordinateur-de-caisse-et-limprimante)
12. [Installer et lier les tablettes](#12-installer-et-lier-les-tablettes)
13. [Saisir les données du restaurant](#13-saisir-les-données-du-restaurant)
14. [Recette : tester avec l'équipe](#14-recette--tester-avec-léquipe)
15. [Le jour J](#15-le-jour-j)
16. [Mises à jour futures](#16-mises-à-jour-futures)
17. [Coûts](#17-coûts)
18. [Dépannage](#18-dépannage)

---

## 0. Ce qu'il faut avant de commencer

### Comptes

| Élément | Pourquoi |
|---|---|
| **Un compte Google dédié au restaurant**, par exemple `chezamani.gestion@gmail.com` (à créer sur <https://accounts.google.com/signup>) | Propriétaire du serveur. Ne pas utiliser un compte personnel : le restaurant doit pouvoir le garder si le prestataire change. Activez la validation en deux étapes. |
| **Une carte bancaire Visa ou Mastercard** acceptée en ligne | La formule Firebase « Blaze » est obligatoire pour les fonctions serveur et les sauvegardes. Pour un restaurant, la facture reste en général nulle ou très faible (voir [§ 17](#17-coûts)). |
| **Un compte GitHub** ayant accès au dépôt `Levi0116/Cr-a-Affiches-` | Pour télécharger le code. |

### Matériel

| Matériel | Conseils |
|---|---|
| **Ordinateur de travail** (Windows 10/11, 8 Go de RAM minimum, 25 Go libres, droits administrateur) | Sert à construire et déployer. Il peut être le même que l'ordinateur de caisse. |
| **Ordinateur de caisse** (Windows, Google Chrome) | Branché sur onduleur si possible. |
| **Imprimante thermique 80 mm USB** (Epson TM-T20, Xprinter XP-80…) | Avec son pilote Windows. |
| **Tablettes Android** (Android 8 ou plus récent, 10 pouces conseillé) | Une par serveuse ou par zone. |
| **Téléphone Android du gérant** | Reçoit les notifications et valide à distance. |
| **Wi-Fi** couvrant toute la salle et la terrasse, plus une connexion internet (box ou 4G) | L'application continue sans internet, mais tablettes et caisse doivent être sur le même Wi-Fi pour se synchroniser vite. |
| **Câble USB** pour brancher une tablette à l'ordinateur | Pour installer l'application. |

### Choisir les identifiants des projets

Les identifiants Firebase sont **uniques dans le monde entier** ; `resto-prod` est sûrement déjà pris. Ce guide utilise :

- `chez-amani-prod` : vraies données du restaurant ;
- `chez-amani-dev` : essais.

Si Firebase refuse un nom, ajoutez un suffixe (`chez-amani-prod-226`, par exemple) et utilisez votre nom partout dans la suite.

---

## 1. Installer les outils sur l'ordinateur de travail

### 1.1 Ouvrir PowerShell en administrateur

🖱️ Menu Démarrer → tapez **PowerShell** → clic droit sur « Windows PowerShell » → **Exécuter en tant qu'administrateur**.

⌨️ Autoriser les scripts des outils (npm, firebase) pour votre compte :

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

### 1.2 Installer les logiciels avec winget

`winget` est fourni avec Windows 10/11. Si la commande est inconnue, installez « App Installer » depuis le Microsoft Store : <https://apps.microsoft.com/detail/9NBLGGH4NNS1>.

⌨️ Copiez tout le bloc :

```powershell
winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
winget install --id EclipseAdoptium.Temurin.21.JDK -e --accept-source-agreements --accept-package-agreements
winget install --id Google.AndroidStudio -e --accept-source-agreements --accept-package-agreements
winget install --id Google.CloudSDK -e --accept-source-agreements --accept-package-agreements
winget install --id Google.Chrome -e --accept-source-agreements --accept-package-agreements
```

| Logiciel | Rôle | Page officielle (installation manuelle) |
|---|---|---|
| Git | télécharger le code | <https://git-scm.com/download/win> |
| Node.js (LTS, version 22 ou plus) | fonctions serveur, outils Firebase | <https://nodejs.org/fr/download> |
| Java 21 (Temurin) | émulateur Firebase pour les tests | <https://adoptium.net/fr/temurin/releases/?version=21> |
| Android Studio | SDK Android pour construire l'APK | <https://developer.android.com/studio> |
| Google Cloud CLI | sauvegardes (bucket de stockage) | <https://cloud.google.com/sdk/docs/install?hl=fr> |
| Google Chrome | caisse web | <https://www.google.com/chrome/> |

⚠️ **Fermez PowerShell et rouvrez-le** (toujours en administrateur) pour que les nouvelles commandes soient reconnues.

### 1.3 Installer Flutter 3.50

L'application a été construite et testée avec **Flutter 3.50.0** (canal stable). Utilisez cette version.

⌨️

```powershell
New-Item -ItemType Directory -Force C:\src | Out-Null
git clone https://github.com/flutter/flutter.git -b 3.50.0 C:\src\flutter
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";C:\src\flutter\bin", "User")
```

Si la branche `3.50.0` n'existe pas, remplacez-la par `stable`.

Documentation officielle : <https://docs.flutter.dev/get-started/install/windows/mobile>

⚠️ Fermez et rouvrez PowerShell.

### 1.4 Préparer Android Studio

1. 🖱️ Lancez **Android Studio** une première fois et laissez l'assistant « Standard » installer le SDK Android (quelques Go).
2. 🖱️ Ensuite : **More Actions → SDK Manager → SDK Tools**, cochez **Android SDK Command-line Tools (latest)** → **Apply**.
3. ⌨️ Acceptez les licences et vérifiez l'installation :

```powershell
flutter doctor --android-licenses
flutter doctor
```

Tapez `y` à chaque question.

✅ `flutter doctor` doit afficher des coches vertes pour **Flutter**, **Android toolchain** et **Chrome**. Les lignes « Visual Studio » ou « Windows » peuvent rester en jaune : elles ne servent pas ici.

### 1.5 Installer les outils Firebase

⌨️

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";$env:LOCALAPPDATA\Pub\Cache\bin", "User")
```

⚠️ Fermez et rouvrez PowerShell, puis vérifiez :

```powershell
node --version
firebase --version
flutterfire --version
gcloud --version
java -version
```

✅ Chaque commande affiche un numéro de version (Node v22 ou plus, Java 21).

---

## 2. Récupérer le code de la plateforme

⌨️

```powershell
cd C:\src
git clone https://github.com/Levi0116/Cr-a-Affiches-.git amani
cd C:\src\amani
git checkout ccr-7324c1b1-dnzjuz
cd gestion_restaurant
flutter pub get
```

Une fenêtre de connexion GitHub peut s'ouvrir si le dépôt est privé : connectez-vous avec le compte qui y a accès.

> Une fois la branche fusionnée dans `main`, remplacez `git checkout ccr-7324c1b1-dnzjuz` par `git checkout main`.

**Toutes les commandes suivantes se lancent depuis `C:\src\amani\gestion_restaurant`**, sauf mention contraire.

---

## 3. Vérifier que tout fonctionne (tests)

⌨️ Tests de l'application (31 tests) :

```powershell
cd C:\src\amani\gestion_restaurant
flutter test
```

✅ `All tests passed!`

⌨️ Tests du serveur sur l'émulateur Firebase (14 tests : règles de sécurité et fonctions) :

```powershell
cd C:\src\amani\gestion_restaurant\functions
npm install
npm test
cd ..
```

✅ `# pass 14` puis `# fail 0`.

Si le pare-feu Windows demande d'autoriser Java ou Node, cliquez sur **Autoriser** (réseaux privés).

---

## 4. Créer les projets Firebase (serveur en ligne)

Connectez-vous à <https://console.firebase.google.com> avec le **compte Google du restaurant**.

Faites les étapes 4.1 à 4.6 **deux fois** : pour `chez-amani-dev`, puis pour `chez-amani-prod`.

### 4.1 Créer le projet

1. 🖱️ **Créer un projet**.
2. Nom : `chez-amani-prod`. Sous le nom, vérifiez l'**identifiant** affiché : c'est lui qui compte. Notez-le.
3. Google Analytics : **désactivé** (inutile ici).
4. **Créer le projet**.

### 4.2 Passer en formule Blaze et créer une alerte de budget

1. 🖱️ En bas à gauche : **Spark** → **Mettre à niveau** → **Blaze** → associez la carte bancaire.
2. Créez tout de suite une **alerte de budget** :
   - 🖱️ <https://console.cloud.google.com/billing> → votre compte de facturation → **Budgets et alertes** → **Créer un budget**.
   - Champ d'application : le projet. Montant : **10 €** par mois (environ 6 500 F CFA).
   - Seuils : 50 %, 90 %, 100 %.
   - Vous recevrez un e-mail si les coûts approchent ce montant. Une alerte ne coupe pas le service.

### 4.3 Base de données Firestore

1. 🖱️ Menu **Créer → Firestore Database** → **Créer une base de données**.
2. Édition : **Standard**. Identifiant : `(default)`.
3. Emplacement : **`europe-west1` (Belgique)**. ⚠️ Ce choix est définitif et doit correspondre au code (`REGION` dans `functions/src/commun.ts`).
4. Mode : **production**. Les vraies règles seront déployées à l'étape 6.

### 4.4 Authentification anonyme

🖱️ **Créer → Authentication → Commencer → Méthode de connexion → Anonyme → Activer → Enregistrer.**

Les appareils s'identifient ainsi avant d'être liés ; les employés se connectent ensuite avec leur PIN.

### 4.5 Autres services

- 🖱️ **Exécuter → Crashlytics** : cliquez sur **Commencer** (rapports de plantage des tablettes).
- **Cloud Messaging** (notifications) est actif par défaut.
- **Hosting** s'active au premier déploiement.

### 4.6 Vérifier l'identifiant exact

🖱️ Roue dentée → **Paramètres du projet** → « ID du projet ». Notez-le exactement.

---

## 5. Relier le code aux projets

### 5.1 Se connecter

⌨️

```powershell
cd C:\src\amani\gestion_restaurant
firebase login
gcloud auth login
```

Le navigateur s'ouvre : choisissez le **compte Google du restaurant** et acceptez.

### 5.2 Déclarer les deux projets

⌨️ Remplacez les identifiants si vous en avez choisi d'autres :

```powershell
$DEV  = "chez-amani-dev"
$PROD = "chez-amani-prod"
@"
{
  "projects": {
    "dev": "$DEV",
    "prod": "$PROD"
  }
}
"@ | Set-Content -Encoding utf8 .firebaserc
firebase projects:list
```

✅ Vos deux projets apparaissent dans la liste.

### 5.3 Brancher l'application Android et web

⌨️ D'abord sur le projet **d'essai** :

```powershell
flutterfire configure --project=chez-amani-dev --platforms=android,web --yes
```

Cette commande :

- crée les applications Android (`ci.resto.gestion_restaurant`) et Web dans Firebase ;
- remplace `lib\firebase_options.dart` ;
- ajoute `android\app\google-services.json` ;
- ajoute les modules Gradle de Firebase (dont Crashlytics).

Pour la production, vous relancerez la même commande avec `--project=chez-amani-prod` (étape 6.3).

---

## 6. Déployer le serveur (règles + fonctions)

### 6.1 D'abord sur le projet d'essai

⌨️

```powershell
cd C:\src\amani\gestion_restaurant
firebase use dev
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

- Le premier déploiement des fonctions **active plusieurs services Google** (Cloud Build, Artifact Registry, Cloud Scheduler, Eventarc…) et peut prendre **5 à 10 minutes**.
- Si un message demande d'activer une API, répondez `Y`.
- S'il propose une **politique de nettoyage des images** (« cleanup policy »), répondez `Y` avec **1 jour** : cela évite de payer du stockage inutile.
- ⚠️ Une erreur de permission au tout premier essai est fréquente (les services viennent d'être activés). **Attendez 2 minutes et relancez** la même commande.

✅ `Deploy complete!`. Dans la console → **Functions**, vous voyez 9 fonctions :

- `lierAppareil`, `creerCodeLiaison`, `elevationAdmin`, `finElevationAdmin`, `revoquerAppareil` ;
- `surveillerStock`, `notifierDemande`, `rapportJour`, `sauvegardeQuotidienne`.

### 6.2 Essai complet sur `dev` (fortement conseillé)

Faites les étapes 8 à 12 avec le projet d'essai, et testez une soirée fictive. Quand tout va bien, passez en production.

### 6.3 En production

⌨️

```powershell
cd C:\src\amani\gestion_restaurant
flutterfire configure --project=chez-amani-prod --platforms=android,web --yes
firebase use prod
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

⚠️ **Avant chaque déploiement**, vérifiez le projet actif avec `firebase use`. Il doit afficher `prod` quand vous visez les vraies données.

---

## 7. Activer les sauvegardes quotidiennes

La fonction `sauvegardeQuotidienne` exporte toute la base chaque jour à **4 h** (heure de Ouagadougou) dans un espace de stockage nommé `gs://<projet>-sauvegardes`. Il faut créer cet espace et donner les droits à la fonction.

⌨️ À faire **une fois sur le projet de production** :

```powershell
$PROD = "chez-amani-prod"
gcloud config set project $PROD

# 1. Espace de stockage dans la même région que la base
gcloud storage buckets create "gs://$PROD-sauvegardes" --location=europe-west1 --uniform-bucket-level-access

# 2. Conserver 14 jours, puis supprimer automatiquement
'{"rule":[{"action":{"type":"Delete"},"condition":{"age":14}}]}' | Set-Content -Encoding ascii cycle.json
gcloud storage buckets update "gs://$PROD-sauvegardes" --lifecycle-file=cycle.json
Remove-Item cycle.json

# 3. Droits du compte de service des fonctions
$NUMERO = gcloud projects describe $PROD --format="value(projectNumber)"
$COMPTE = "$NUMERO-compute@developer.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROD --member="serviceAccount:$COMPTE" --role="roles/datastore.importExportAdmin"
gcloud storage buckets add-iam-policy-binding "gs://$PROD-sauvegardes" --member="serviceAccount:$COMPTE" --role="roles/storage.admin"
```

✅ **Tester tout de suite**, sans attendre 4 h du matin :

🖱️ <https://console.cloud.google.com/cloudscheduler> (projet `chez-amani-prod`) → ligne contenant `sauvegardeQuotidienne` → menu ⋮ → **Forcer l'exécution**.

Une ou deux minutes plus tard, un dossier daté doit apparaître dans <https://console.cloud.google.com/storage/browser>, dans le bucket `chez-amani-prod-sauvegardes`.

> **Restaurer une sauvegarde** (en cas de catastrophe uniquement) :
> `gcloud firestore import gs://chez-amani-prod-sauvegardes/AAAA-MM-JJ`

---

## 8. Construire l'application Android (APK)

### 8.1 Créer la clé de signature (une seule fois, à vie)

⚠️ **Cette clé est irremplaçable.** Sans elle, aucune mise à jour de l'application ne pourra jamais être installée sur les tablettes. Faites-en **trois copies** : clé USB, Google Drive du restaurant, et une copie chez le gérant.

⌨️

```powershell
New-Item -ItemType Directory -Force C:\cles | Out-Null
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore C:\cles\amani-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias amani
```

- `keytool` demande un **mot de passe** (au moins 6 caractères ; notez-le dans un endroit sûr).
- Il demande ensuite nom, organisation, ville (Ouagadougou) et pays (`BF`), puis `oui` pour confirmer.

⌨️ Indiquer la clé au projet. Remplacez `VOTRE_MOT_DE_PASSE` par le vôtre :

```powershell
cd C:\src\amani\gestion_restaurant
@"
storePassword=VOTRE_MOT_DE_PASSE
keyPassword=VOTRE_MOT_DE_PASSE
keyAlias=amani
storeFile=C:/cles/amani-release.jks
"@ | Set-Content -Encoding ascii android\key.properties
```

Ce fichier est exclu de Git : il ne sera jamais publié. Le projet est déjà configuré pour l'utiliser automatiquement (`android/app/build.gradle.kts`).

### 8.2 Construire l'APK de production

⌨️

```powershell
cd C:\src\amani\gestion_restaurant
flutter build apk --release --dart-define=FIREBASE=true
```

La première construction prend 5 à 15 minutes.

✅ Le fichier se trouve ici :

```
C:\src\amani\gestion_restaurant\build\app\outputs\flutter-apk\app-release.apk
```

⚠️ `--dart-define=FIREBASE=true` est **indispensable**. Sans cette option, l'application démarre en mode démonstration, avec des données fictives non enregistrées.

---

## 9. Mettre en ligne la caisse (web)

⌨️

```powershell
cd C:\src\amani\gestion_restaurant
firebase use prod
flutter build web --release --no-web-resources-cdn --dart-define=FIREBASE=true
firebase deploy --only hosting
```

✅ L'adresse de la caisse s'affiche : **`https://chez-amani-prod.web.app`**. Ouvrez-la dans Chrome : l'écran « Lier cet appareil » doit apparaître.

- `--no-web-resources-cdn` embarque tout le moteur d'affichage : la caisse se recharge même si internet est coupé.
- Domaine personnalisé (facultatif) : console → **Hosting → Ajouter un domaine personnalisé** (par exemple `caisse.chezamani.bf`).

---

## 10. Créer le restaurant et lier le téléphone du gérant

Le script de création affiche un **code de liaison valable 15 minutes**. Installez donc d'abord l'application sur le téléphone du gérant.

### 10.1 Installer l'APK sur le téléphone du gérant

**Méthode A, par câble (la plus simple pour plusieurs appareils) :**

1. Sur le téléphone : **Paramètres → À propos du téléphone** → tapez 7 fois sur **Numéro de build** (les options développeur s'activent).
2. **Paramètres → Système → Options pour les développeurs** → activez **Débogage USB**.
3. Branchez le téléphone en USB et acceptez « Autoriser le débogage USB » sur l'écran du téléphone.
4. ⌨️ Installez l'application :

```powershell
$ADB = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $ADB devices
& $ADB install -r C:\src\amani\gestion_restaurant\build\app\outputs\flutter-apk\app-release.apk
```

✅ `Success`.

**Méthode B, sans câble :** envoyez `app-release.apk` sur le téléphone (Google Drive, WhatsApp en document, clé USB). Ouvrez-le, autorisez « Installer des applications inconnues » pour cette source, puis **Installer**.

### 10.2 Créer une clé de service (temporaire)

1. 🖱️ Console Firebase → `chez-amani-prod` → roue dentée → **Paramètres du projet → Comptes de service → Générer une nouvelle clé privée**.
2. Enregistrez le fichier sous **`C:\cles\chez-amani-prod.json`**.
3. ⚠️ **Ne jamais le mettre dans Git** ni l'envoyer par WhatsApp ou e-mail. Il donne un accès total à la base.

### 10.3 Lancer la création

Choisissez le **PIN à 4 chiffres** du gérant. Ne gardez pas `4826`, qui n'est qu'un exemple.

⌨️

```powershell
cd C:\src\amani\gestion_restaurant\functions
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\cles\chez-amani-prod.json"
npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --telephone "+226 65 91 11 76" --admin "Patron" --pin 4826
```

✅ Le script affiche un **code de liaison à 6 caractères** (par exemple `K7P2QX`).

### 10.4 Lier le téléphone (dans les 15 minutes)

1. Sur le téléphone du gérant, ouvrez **Chez les Amani** → **Lier cet appareil** → tapez le code.
2. Autorisez les **notifications** quand Android le demande.
3. Connectez-vous avec **Patron** et le PIN choisi.

✅ Le téléphone a les **droits administrateur permanents**. C'est lui qui liera tous les autres appareils.

Si le code a expiré : supprimez le restaurant dans la console (Firestore → `restaurants/chez-amani`), puis relancez 10.3.

### 10.5 Supprimer la clé de service

⌨️

```powershell
Remove-Item Env:\GOOGLE_APPLICATION_CREDENTIALS
Remove-Item C:\cles\chez-amani-prod.json
```

🖱️ Puis dans la console : **Comptes de service** → lien « Gérer les autorisations… » → compte `firebase-adminsdk` → onglet **Clés** → supprimez la clé créée.

---

## 11. Préparer l'ordinateur de caisse et l'imprimante

### 11.1 Imprimante thermique 80 mm

1. Installez le **pilote Windows** du fabricant :
   - Epson : <https://epson.com/Support/Point-of-Sale/sh/s1>
   - Xprinter : <https://www.xprintertech.com/drivers-2>
2. 🖱️ **Paramètres → Bluetooth et appareils → Imprimantes et scanners** → choisissez l'imprimante → **Définir par défaut**. Désactivez « Laisser Windows gérer mon imprimante par défaut ».
3. 🖱️ **Préférences d'impression** → format papier **80 mm × rouleau** (ou « 80 × 297 mm »), marges minimales.
4. Imprimez une page de test.

⌨️ Vérifier l'imprimante par défaut :

```powershell
Get-CimInstance Win32_Printer | Where-Object Default | Select-Object Name
```

### 11.2 Raccourci « Caisse » (impression directe, sans fenêtre)

⌨️ Crée un raccourci sur le Bureau **et** au démarrage de Windows. Remplacez l'adresse si besoin :

```powershell
$URL    = "https://chez-amani-prod.web.app"
$CHROME = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$ARGS   = "--kiosk-printing --app=$URL"
$shell  = New-Object -ComObject WScript.Shell
foreach ($dossier in @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Startup"))) {
  $lnk = $shell.CreateShortcut("$dossier\Caisse Chez les Amani.lnk")
  $lnk.TargetPath = $CHROME
  $lnk.Arguments  = $ARGS
  $lnk.IconLocation = "$CHROME,0"
  $lnk.Save()
}
```

`--kiosk-printing` imprime le ticket directement sur l'imprimante par défaut. ⚠️ Fermez toutes les fenêtres Chrome avant d'ouvrir le raccourci la première fois, sinon l'option est ignorée.

### 11.3 Empêcher la mise en veille pendant le service

⌨️

```powershell
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
```

### 11.4 Lier la caisse

1. Sur le **téléphone du gérant** : **Administration → Appareils → Lier un appareil** → type **Caisse** → nom « Caisse principale ». Un QR code et un code à 6 caractères s'affichent.
2. Sur l'ordinateur de caisse : ouvrez le raccourci → **Lier cet appareil** → tapez le code (ou scannez le QR code avec la webcam).

✅ L'écran de connexion PIN de la caisse apparaît.

---

## 12. Installer et lier les tablettes

Pour **chaque tablette** :

1. Installez l'APK comme au [§ 10.1](#101-installer-lapk-sur-le-téléphone-du-gérant).

   ⌨️ Avec plusieurs tablettes branchées en même temps :

   ```powershell
   $ADB = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
   $APK = "C:\src\amani\gestion_restaurant\build\app\outputs\flutter-apk\app-release.apk"
   & $ADB devices | Select-String "device$" | ForEach-Object { $id = ($_ -split "\s+")[0]; & $ADB -s $id install -r $APK }
   ```

2. Sur le téléphone du gérant : **Administration → Appareils → Lier un appareil** → type **Tablette** → nom (« Tablette Salle 1 »).
3. Sur la tablette : **Lier cet appareil** → **Scanner le QR code** (autorisez la caméra) ou tapez le code.

Réglages conseillés sur chaque tablette :

- **Affichage → Mise en veille de l'écran** : 10 minutes.
- **Batterie** : désactivez l'optimisation pour « Chez les Amani ».
- Wi-Fi du restaurant **mémorisé** ; désactivez les mises à jour automatiques d'Android pendant les heures de service.
- **Épinglage d'écran** (facultatif) pour que la tablette reste sur l'application.

Une tablette perdue ou volée se retire à distance : **Administration → Appareils → Retirer**.

---

## 13. Saisir les données du restaurant

Connecté en **Patron** (sur la caisse ou le téléphone) :

| Ordre | Écran | À saisir |
|---|---|---|
| 1 | **Administration → Paramètres** | Adresse, téléphone, mentions et bas du ticket, TVA (oui/non, 18 %), délai de déconnexion automatique |
| 2 | **Tables et zones** | Zones (Salle, Terrasse, VIP…), puis tables numérotées dans chaque zone |
| 3 | **Menu** | Catégories (Bières, Sucreries, Plats, Grillades…), puis articles avec prix ; favoris pour les plus vendus |
| 4 | **Stock** | Pour chaque boisson : quantité de départ, seuil d'alerte, bouteilles par casier, coût d'achat ; consignes (vides) |
| 5 | **Menu → fiches techniques** (facultatif) | Ingrédients consommés par les plats |
| 6 | **Employés** | Une fiche par personne : nom, rôle (serveuse, caissier, gestionnaire de stock, administrateur), **PIN personnel** |
| 7 | **Caisse → Journée** | Ouverture avec le comptage du fond de caisse |

Conseils :

- Faites l'**inventaire réel** du stock la veille de la mise en service.
- Chaque employé choisit son PIN **devant vous** et le garde secret.

---

## 14. Recette : tester avec l'équipe

Déroulez **toute la liste de [RECETTE.md](RECETTE.md)** avec le vrai matériel, en particulier :

- une soirée simulée avec 3 tablettes et une centaine de commandes ;
- le **mode avion** sur une tablette pendant une commande, puis le retour du réseau ;
- la coupure du Wi-Fi pendant 30 minutes ;
- l'impression des tickets, pré-additions et clôture ;
- une annulation validée depuis le téléphone du gérant ;
- la clôture de caisse avec écart.

Signez le procès-verbal en bas de RECETTE.md. Ensuite, **remettez les données à zéro** :

- supprimez les ventes de test, ou plus simplement recréez le restaurant avec un autre identifiant (par exemple `chez-amani-2026`) ;
- ou faites la recette sur `chez-amani-dev` et ne touchez à la production que pour la vraie mise en service.

---

## 15. Le jour J

Avant le service :

- [ ] Inventaire du stock à jour dans l'application.
- [ ] Caisse ouverte avec le fond compté.
- [ ] Tablettes chargées, connectées au Wi-Fi, employés connectés avec leur PIN.
- [ ] Rouleaux de papier thermique de rechange.
- [ ] **Plan B papier** (carnet + calculatrice) rangé à la caisse, au cas où.
- [ ] Le prestataire joignable par téléphone pendant le premier service.

Après le service : clôture de caisse, rapport du jour, export Excel du rapport pour le gérant.

---

## 16. Mises à jour futures

1. Modifier le code, puis augmenter la version dans `pubspec.yaml` (exemple : `version: 1.1.0+2`).
2. Tester sur `dev` (`firebase use dev`, mêmes commandes).
3. Le matin, hors service, sur la production :

```powershell
cd C:\src\amani\gestion_restaurant
git pull
flutter pub get
firebase use prod
firebase deploy --only firestore:rules,firestore:indexes,functions
flutter build web --release --no-web-resources-cdn --dart-define=FIREBASE=true
firebase deploy --only hosting
flutter build apk --release --dart-define=FIREBASE=true
```

4. Publier le nouvel APK à une adresse de téléchargement (Google Drive en lien public, par exemple), puis dans la console → **Firestore** → collection `config`, document `version`, renseigner :

   | Champ | Valeur |
   |---|---|
   | `derniere` | `1.1.0` |
   | `minimale` | `1.0.0` |
   | `urlApk` | `https://…/app-release.apk` |
   | `notes` | `Ce qui change` |

   Tablettes et caisse affichent alors « Nouvelle version disponible ».
5. En cas de problème : console → **Hosting → Historique des versions → Restaurer** ; tablettes : réinstaller l'APK précédent (gardez toujours le précédent).
6. Noter les changements dans `CHANGELOG.md`.

---

## 17. Coûts

| Élément | Coût |
|---|---|
| Firebase (formule Blaze) | Les quotas gratuits quotidiens restent inclus et couvrent normalement l'activité d'un seul restaurant (Firestore, fonctions, hébergement, notifications). L'alerte de budget prévient en cas de surprise. Tarifs : <https://firebase.google.com/pricing?hl=fr> |
| Stockage des sauvegardes | Quelques centimes d'euro par mois (14 jours conservés) |
| Domaine personnalisé (facultatif) | Selon le registraire, par an |
| Google Play (facultatif, plus tard) | 25 $ une fois ; inutile pour un seul restaurant (installation directe de l'APK) |

Pour surveiller : console → **Utilisation et facturation**.

---

## 18. Dépannage

| Problème | Solution |
|---|---|
| `firebase : impossible de charger le fichier … l'exécution de scripts est désactivée` | Refaire `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force` |
| `'flutter' n'est pas reconnu` | Fermer et rouvrir PowerShell ; vérifier que `C:\src\flutter\bin` est dans le Path (`$env:Path -split ";"`) |
| `flutterfire` introuvable | Vérifier que `%LOCALAPPDATA%\Pub\Cache\bin` est dans le Path, puis rouvrir PowerShell |
| `npm test` : « Could not spawn java » | Java 21 manquant : `winget install --id EclipseAdoptium.Temurin.21.JDK -e`, puis rouvrir PowerShell |
| Premier `firebase deploy --only functions` en erreur de permissions | Attendre 2 à 5 minutes et relancer (les services Google s'activent) |
| `Error: Your project … must be on the Blaze plan` | Étape 4.2 non faite |
| L'application affiche des données fictives | APK ou caisse construits sans `--dart-define=FIREBASE=true` : reconstruire |
| « Lier cet appareil » : code refusé | Code expiré (15 min) ou déjà utilisé : en générer un nouveau depuis le téléphone du gérant |
| Le ticket ouvre une fenêtre d'impression | Chrome n'a pas été lancé par le raccourci `--kiosk-printing` : fermer toutes les fenêtres Chrome et relancer le raccourci |
| Ticket trop petit ou coupé | Préférences de l'imprimante : papier 80 mm, échelle 100 %, marges minimales |
| Pas de notification sur le téléphone du gérant | Autoriser les notifications pour l'application ; désactiver l'optimisation de batterie ; vérifier qu'il a été lié comme téléphone administrateur |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` lors de l'installation | APK signé avec une autre clé : désinstaller l'ancienne application (les données sont sur le serveur), puis réinstaller |
| La sauvegarde n'apparaît pas | Revoir l'étape 7.3 (droits) ; console → Functions → `sauvegardeQuotidienne` → **Journaux** |
| Tout le reste | Console Firebase → **Functions → Journaux** et **Crashlytics** ; noter l'heure et l'écran concerné |

---

### Récapitulatif des fichiers secrets (jamais dans Git, jamais par messagerie)

| Fichier | Où le garder |
|---|---|
| `C:\cles\amani-release.jks` + mot de passe | 3 copies en lieu sûr : **indispensable à vie** |
| `android\key.properties` | Uniquement sur l'ordinateur qui construit l'APK |
| Clé de service `*.json` | Supprimée après le § 10 |
| PIN du gérant | Le gérant seul |
