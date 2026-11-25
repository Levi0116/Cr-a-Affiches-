# Mise en ligne — Restaurant Chez les Amani

**Application, domaine et e-mails chez LWS · Serveur Node.js et base de données chez alwaysdata (gratuit)**

Ce guide se suit **dans l'ordre**, étape par étape. Comptez **1 h 30 à 2 h** la première fois.

---

## 0. Vue d'ensemble

```
   Tablettes · Caisse · Téléphone du gérant
                    │
                    ▼
 ┌─────────────────────────────────────────────┐
 │ LWS (formule Perso, déjà payée)             │
 │  • restaurant-chez-amani.com  → l'APPLICATION│  ← fichiers de amani-front-lws.zip
 │  • contact@restaurant-chez-amani.com → E-MAILS│
 └─────────────────────────────────────────────┘
                    │  l'application appelle le serveur
                    │  (adresse écrite dans config.json)
                    ▼
 ┌─────────────────────────────────────────────┐
 │ alwaysdata (offre gratuite)                 │
 │  • VOTRE-COMPTE.alwaysdata.net → SERVEUR    │  ← amani-serveur-alwaysdata.tar.gz
 │    Node.js (API, sécurité, synchronisation) │
 │  • Base MariaDB (compatible MySQL) → DONNÉES│
 └─────────────────────────────────────────────┘
```

### Les 3 liaisons à faire (§ 3)

| Liaison | Où on la règle |
|---|---|
| ① Serveur → base de données | Fichier `.env` du serveur, créé par l'assistant `npm run configurer` |
| ② Application → serveur | Fichier `config.json` de l'application, chez LWS |
| ③ Le serveur accepte l'application | Ligne `ORIGINES` du fichier `.env` (réglée par l'assistant) |

### Ce qu'il vous faut

- un **PC Windows 10 ou 11**, sans rien à installer (PowerShell et SSH sont inclus dans Windows) ;
- les fichiers **`amani-front-lws.zip`** et **`amani-serveur-alwaysdata.tar.gz`**, à enregistrer dans **Téléchargements** ;
- votre accès à l'**espace client LWS** : <https://panel.lws.fr> ;
- une adresse e-mail pour créer le compte alwaysdata ;
- **FileZilla** (gratuit) pour envoyer l'application chez LWS : <https://filezilla-project.org> → « Download FileZilla Client ».

### Notez au fur et à mesure

| Information | Votre valeur |
|---|---|
| Nom du compte alwaysdata (ex. `chezamani`) | .............................. |
| Mot de passe du compte alwaysdata | (gardez-le pour vous) |
| Nom de la base (ex. `chezamani_amani`) | .............................. |
| Mot de passe de la base | (gardez-le pour vous) |
| Code administrateur de l'application (6 à 10 chiffres) | (gardez-le pour vous) |

> Dans tout le guide, remplacez **`VOTRE-COMPTE`** par votre nom de compte alwaysdata.

---

# PARTIE 1 — Le serveur et la base chez alwaysdata

## Étape 1 — Créer le compte gratuit

1. Allez sur <https://www.alwaysdata.com/fr/> → **Inscription**.
2. Choisissez l'offre **gratuite** (Free) et un **nom de compte** court, en minuscules, par exemple `chezamani`. Il formera l'adresse de votre serveur : `https://chezamani.alwaysdata.net`.
3. Validez votre e-mail, puis connectez-vous à l'**interface d'administration** : <https://admin.alwaysdata.com>.

## Étape 2 — Choisir la version de Node.js

1. Menu **Environnement** (en anglais : *Environment*), section **Node.js**.
2. Version par défaut : **22** (ou la plus récente proposée, au moins 20).
3. **Enregistrer**.

## Étape 3 — Créer la base de données

1. Menu **Bases de données → MySQL** (MariaDB), puis **Ajouter une base de données**.
2. **Nom** : `amani`. alwaysdata le préfixe automatiquement ; vous obtenez **`VOTRE-COMPTE_amani`**. Notez-le.
3. **Droits** : cochez l'utilisateur **`VOTRE-COMPTE`**, avec tous les droits. **Valider**.
4. Onglet **Utilisateurs** :
   - si vous ne connaissez pas le mot de passe de l'utilisateur `VOTRE-COMPTE`, modifiez-le et choisissez-en un **long** ;
   - notez-le, c'est le **mot de passe de la base**.

> Le serveur de base de données s'appelle **`mysql-VOTRE-COMPTE.alwaysdata.net`**. L'adresse exacte est affichée en haut de la page **Bases de données → MySQL**.

## Étape 4 — Activer l'accès SSH

1. Menu **Accès distant → SSH**.
2. Modifiez l'utilisateur **`VOTRE-COMPTE`** et cochez **« Activer la connexion par mot de passe »**. **Valider**.
3. Le serveur SSH est **`ssh-VOTRE-COMPTE.alwaysdata.net`**.

## Étape 5 — Envoyer le serveur

Ouvrez **PowerShell** sur le PC (menu Démarrer → tapez *PowerShell*). Remplacez `VOTRE-COMPTE` sur la première ligne, puis copiez-collez le bloc :

```powershell
$COMPTE = "VOTRE-COMPTE"
scp "$env:USERPROFILE\Downloads\amani-serveur-alwaysdata.tar.gz" "${COMPTE}@ssh-${COMPTE}.alwaysdata.net:"
ssh "${COMPTE}@ssh-${COMPTE}.alwaysdata.net"
```

- À la question `Are you sure you want to continue connecting`, tapez **`yes`**.
- Tapez le **mot de passe du compte alwaysdata** (rien ne s'affiche pendant la frappe, c'est normal). Il est demandé deux fois : pour l'envoi, puis pour la connexion.
- ✅ Vous êtes connecté quand la ligne affiche `VOTRE-COMPTE@ssh…:~$`.

## Étape 6 — Installer et relier le serveur à la base (liaison ①)

Toujours dans la même fenêtre :

```bash
tar -xzf amani-serveur-alwaysdata.tar.gz
cd amani-serveur
node -v
npm run configurer
```

`node -v` doit afficher **v20** ou plus. Sinon, revenez à l'étape 2.

L'assistant pose 6 questions. Appuyez sur **Entrée** pour accepter la proposition entre crochets :

| Question | Réponse |
|---|---|
| Nom de votre compte alwaysdata | `VOTRE-COMPTE` |
| Serveur de la base | Entrée (propose `mysql-VOTRE-COMPTE.alwaysdata.net`) |
| Nom de la base | Entrée (propose `VOTRE-COMPTE_amani`) |
| Utilisateur de la base | Entrée (propose `VOTRE-COMPTE`) |
| Mot de passe de la base | celui de l'étape 3 |
| Adresse(s) de l'application | Entrée (propose `https://restaurant-chez-amani.com,https://www.restaurant-chez-amani.com`) |

✅ L'assistant affiche :

- **« Vérification de la connexion à la base… OK »** : la **liaison ①** est faite ;
- **« Fichier .env créé »** : il contient la **liaison ③** (`ORIGINES`) et un secret de sécurité généré automatiquement ;
- **« Tables créées »**.

Si vous voyez « ÉCHEC », relisez le message : la cause est presque toujours un mot de passe, un nom de base ou un nom de serveur. Relancez `npm run configurer`.

## Étape 7 — Créer le restaurant et votre compte administrateur

Choisissez **votre code administrateur** : 6 à 10 chiffres, connu de vous seul. Pas de suite (`123456`) ni de répétition (`111111`). Remplacez `739264` par votre code :

```bash
npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --admin "Patron" --pin 739264 --telephone "+226 65 91 11 76"
```

✅ Un **code de liaison de 8 caractères** s'affiche. Il est valable **15 minutes** : vous l'utiliserez à l'étape 13. Pas d'inquiétude s'il expire : un nouveau code se crée en une commande (étape 13).

## Étape 8 — Démarrer le serveur (site Node.js)

Dans l'**interface alwaysdata**, menu **Web → Sites** :

1. Un site existe déjà pour **`VOTRE-COMPTE.alwaysdata.net`** : cliquez sur l'icône **Modifier** (le crayon). S'il n'existe pas, cliquez sur **Ajouter un site** avec cette adresse.
2. Remplissez :

   | Champ | Valeur |
   |---|---|
   | **Adresses** | `VOTRE-COMPTE.alwaysdata.net` |
   | **Type** | **Node.js** |
   | **Commande** | `node /home/VOTRE-COMPTE/amani-serveur/src/index.js` |
   | **Répertoire de travail** | `/home/VOTRE-COMPTE/amani-serveur` |
   | Version de Node.js | 22 (ou celle de l'étape 2) |

3. Laissez les autres champs par défaut, puis **Enregistrer**. Le site redémarre.

✅ **Vérification** : ouvrez dans le navigateur **`https://VOTRE-COMPTE.alwaysdata.net/api/sante`**. La page doit afficher `{"ok":true,"version":"2.0.0"}`.

> La page affiche une erreur ? Menu **Web → Sites** → votre site → **Journaux** (logs). Le message indique la cause, envoyez-m'en une capture.

---

# PARTIE 2 — Le domaine, les e-mails et l'application chez LWS

## Étape 9 — Activer le HTTPS gratuit (cadenas)

1. Espace client LWS → **restaurant-chez-amani.com** → **Certificat SSL** (ou « Sécurité / SSL »).
2. Activez le **certificat SSL gratuit Let's Encrypt** pour `restaurant-chez-amani.com` **et** `www.restaurant-chez-amani.com`.
3. L'activation prend de quelques minutes à une heure.

> Le domaine pointe déjà vers votre hébergement Perso (serveurs DNS `ns17` à `ns20.lwsdns.com`) : **aucun réglage DNS à faire**.

## Étape 10 — Créer les adresses e-mail

1. Espace client LWS → **restaurant-chez-amani.com** → **E-mails** (ou « Adresses mails ») → **Créer une adresse**.
2. Exemples : `contact@restaurant-chez-amani.com`, `gerant@restaurant-chez-amani.com`. Choisissez un mot de passe long pour chacune. Vous avez droit à 5 adresses.
3. Pour lire vos e-mails :
   - **dans le navigateur** : bouton **Webmail** de l'espace client ;
   - **sur le téléphone** (Gmail, Outlook, Mail) : ajoutez un compte **IMAP** avec les réglages affichés par LWS (rubrique *Configuration* de l'adresse). En général : serveur entrant **IMAP**, port **993** (SSL) ; serveur sortant **SMTP**, port **465** (SSL) ; identifiant = l'adresse complète.

## Étape 11 — Préparer l'application (liaison ②)

1. Dans **Téléchargements**, faites un clic droit sur **`amani-front-lws.zip`** → **Extraire tout…** → **Extraire**. Vous obtenez le dossier `amani-front-lws`.
2. Ouvrez ce dossier. Faites un clic droit sur **`config.json`** → **Ouvrir avec** → **Bloc-notes**.
3. Remplacez `VOTRE-COMPTE` par votre nom de compte alwaysdata :

   ```json
   {
     "api": "https://chezamani.alwaysdata.net/api/"
   }
   ```

4. **Fichier → Enregistrer**, puis fermez le Bloc-notes.

C'est la **liaison ②** : l'application saura où trouver le serveur.

## Étape 12 — Envoyer l'application chez LWS (FileZilla)

1. **Identifiants FTP** : espace client LWS → votre hébergement → **Accès FTP** (ou « Gestion FTP »). Notez le **serveur FTP**, l'**identifiant** et le **mot de passe** ; créez-en un si besoin.
2. Ouvrez **FileZilla**. En haut, remplissez :
   - **Hôte** : le serveur FTP de LWS ;
   - **Identifiant** et **Mot de passe** ;
   - **Port** : `21`.

   Puis cliquez sur **Connexion rapide**. Acceptez le certificat si FileZilla le demande.
3. À **droite** (le serveur LWS), ouvrez le **dossier du site** : `htdocs` (ou `www` selon l'affichage).
   - Supprimez la page par défaut de LWS : `index.html` ou `default.html`. Ne touchez pas aux dossiers que vous ne connaissez pas.
4. À **gauche** (votre PC), ouvrez le dossier **`Téléchargements\amani-front-lws`**.
5. Sélectionnez **tout son contenu** (Ctrl + A), y compris `.htaccess` et `config.json`. Faites-le **glisser** dans `htdocs` à droite. Attendez la fin du transfert (environ 50 fichiers).

> `.htaccess` invisible dans FileZilla ? Menu **Serveur → Forcer l'affichage des fichiers cachés**.
>
> Sans FileZilla : le **Gestionnaire de fichiers** de l'espace client LWS permet aussi d'envoyer `amani-front-lws.zip` dans `htdocs` puis de le **décompresser**. Modifiez ensuite `config.json` dans ce gestionnaire.

---

# PARTIE 3 — Mettre en connexion et vérifier

## Les 3 liaisons, récapitulées

| # | De → vers | Réglage | Où |
|---|---|---|---|
| ① | Serveur → base | `MYSQL_HOTE`, `MYSQL_BASE`, `MYSQL_UTILISATEUR`, `MYSQL_MOT_DE_PASSE` | `~/amani-serveur/.env` chez alwaysdata (assistant de l'étape 6) |
| ② | Application → serveur | `"api": "https://VOTRE-COMPTE.alwaysdata.net/api/"` | `htdocs/config.json` chez LWS (étape 11) |
| ③ | Le serveur accepte l'application | `ORIGINES=https://restaurant-chez-amani.com,https://www.restaurant-chez-amani.com` | `~/amani-serveur/.env` chez alwaysdata (assistant de l'étape 6) |

Les deux côtés sont en **HTTPS** : alwaysdata l'active tout seul, LWS à l'étape 9.

## Vérifications (dans cet ordre)

1. **`https://VOTRE-COMPTE.alwaysdata.net/api/sante`** → `{"ok":true,...}`. Le serveur et la base fonctionnent (liaison ①).
2. **`https://restaurant-chez-amani.com/config.json`** → votre adresse alwaysdata s'affiche. La liaison ② est en ligne.
3. **`https://restaurant-chez-amani.com`** → le **cadenas** 🔒 et l'écran **« Lier cet appareil »** s'affichent. L'application est en ligne.
4. **Liaison du premier appareil** (étape 13) : si elle réussit, les trois liaisons fonctionnent ensemble.

## Si une liaison ne marche pas

| Symptôme | Liaison | Correction |
|---|---|---|
| `/api/sante` affiche une erreur | ① | Journaux du site alwaysdata ; relancez `npm run configurer`, puis **Redémarrer** le site |
| L'application dit « Pas de connexion au serveur » alors qu'internet fonctionne | ② | Vérifiez `config.json` chez LWS : `https://`, nom de compte exact, se termine par `/api/` |
| La console du navigateur affiche « CORS » | ③ | Dans SSH : `cd ~/amani-serveur && nano .env`. Vérifiez la ligne `ORIGINES` (adresses exactes, avec `https://`, sans `/` final). Enregistrez (Ctrl+O, Entrée, Ctrl+X), puis **Redémarrer** le site |
| Pas de cadenas sur restaurant-chez-amani.com | HTTPS | Étape 9 : attendez l'activation du certificat SSL |

---

# PARTIE 4 — Installer l'application sur les appareils

## Étape 13 — Téléphone du gérant (le premier appareil)

1. Ouvrez **Chrome** → **`https://restaurant-chez-amani.com`**.
2. Menu **⋮** → **Installer l'application**. L'icône **Chez les Amani** apparaît sur l'écran d'accueil.
3. Ouvrez-la, tapez le **code de liaison** de l'étape 7, puis touchez **Patron** → votre code → **✓**.

> Code expiré ? Dans la fenêtre SSH alwaysdata :
>
> ```bash
> cd ~/amani-serveur && npm run code-liaison -- --id chez-amani
> ```

Ce téléphone a les **droits administrateur permanents** et lie tous les autres appareils.

## Étape 14 — Ordinateur de caisse

1. Chrome ou Edge → `https://restaurant-chez-amani.com` → icône **Installer** (à droite de la barre d'adresse).
2. Sur le téléphone du gérant : **Administration → Appareils → Lier un appareil** → type **Caisse**. Tapez le code sur l'ordinateur.
3. Ticket imprimé directement : l'imprimante 80 mm doit être l'imprimante **par défaut** de Windows. Dans PowerShell, sur l'ordinateur de caisse :

```powershell
$URL = "https://restaurant-chez-amani.com"
$CHROME = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$s = New-Object -ComObject WScript.Shell
foreach ($d in @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Startup"))) {
  $l = $s.CreateShortcut("$d\Caisse Chez les Amani.lnk"); $l.TargetPath = $CHROME
  $l.Arguments = "--kiosk-printing --app=$URL"; $l.IconLocation = "$CHROME,0"; $l.Save()
}
powercfg /change standby-timeout-ac 0
```

## Étape 15 — Tablettes des serveuses

Pour chaque tablette :

1. Chrome → l'adresse → **⋮ → Installer l'application**.
2. Téléphone du gérant → **Lier un appareil** → type **Tablette**.
3. Sur la tablette, **scannez le QR code**.

## Étape 16 — Comptes et données

- **Administration → Comptes de l'équipe → Nouveau compte** : un code de 6 à 10 chiffres par employé. Vous seul créez, modifiez et supprimez les comptes.
- Puis **Tables et zones**, **Menu**, **Stock**, **Paramètres** (adresse, texte du ticket).

**Test final** :

1. Commande sur une tablette → elle apparaît à la caisse en quelques secondes.
2. Wi-Fi coupé sur la tablette → elle continue → tout se synchronise au retour du réseau.

---

# PARTIE 5 — Au quotidien

## Sauvegardes de la base

- **alwaysdata** sauvegarde automatiquement votre compte (quelques jours d'historique sur l'offre gratuite) : menu **Sauvegardes** de l'interface.
- **Votre propre copie, chaque semaine** :

  1. Dans SSH (le mot de passe de la base est demandé) :

     ```bash
     mysqldump -h mysql-VOTRE-COMPTE.alwaysdata.net -u VOTRE-COMPTE -p VOTRE-COMPTE_amani | gzip > ~/sauvegarde-$(date +%F).sql.gz
     ```

  2. Puis sur le PC, dans PowerShell :

     ```powershell
     $COMPTE = "VOTRE-COMPTE"
     New-Item -ItemType Directory -Force C:\amani-sauvegardes | Out-Null
     scp "${COMPTE}@ssh-${COMPTE}.alwaysdata.net:sauvegarde-*.sql.gz" C:\amani-sauvegardes\
     ```

## Mettre à jour (quand je vous fournis de nouveaux paquets)

**Serveur** : envoi (étape 5), puis dans SSH :

```bash
tar -xzf amani-serveur-alwaysdata.tar.gz
cd ~/amani-serveur && npm run migrer
```

Puis interface alwaysdata → **Web → Sites** → **Redémarrer**. Le fichier `.env` (vos réglages) n'est jamais écrasé.

**Application** : extraire le nouveau zip, **remettre votre `config.json`** (ou refaire l'étape 11), puis envoyer avec FileZilla en remplaçant les fichiers (étape 12).

## Limites de l'offre gratuite alwaysdata

Ressources modestes, mais suffisantes pour un restaurant. Si un jour le serveur devenait lent ou indisponible, deux possibilités :

- passer à une **offre payante alwaysdata**, sans rien réinstaller ;
- me demander une autre solution.

Les appareils continuent de fonctionner hors ligne en attendant.

---

## Dépannage général

| Problème | Solution |
|---|---|
| `ssh` ou `scp` : « Permission denied » | Mot de passe du compte alwaysdata ; connexion par mot de passe activée (étape 4) |
| `node -v` affiche une vieille version | Étape 2, puis reconnectez-vous en SSH |
| « Code inconnu, expiré ou déjà utilisé » | Nouveau code (encadré de l'étape 13) |
| L'application montre l'ancienne version | Fermez et rouvrez l'application installée (deux fois si besoin) |
| Page blanche sur restaurant-chez-amani.com | Tous les fichiers sont-ils dans `htdocs` (dont `.htaccess`, `main.dart.js`, dossiers `assets` et `canvaskit`) ? |
| Erreur de certificat sur restaurant-chez-amani.com | Le SSL LWS n'est pas encore actif (étape 9) : attendez, ou supprimez temporairement `.htaccess` |

**Pour tout autre message : une capture d'écran et je vous dis quoi faire.**
