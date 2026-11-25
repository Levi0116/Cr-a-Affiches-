# Mise en service — Restaurant Chez les Amani (version 2)

**PWA + serveur Node.js + base MySQL/MariaDB.** On procède en deux temps :

1. **Partie A — tester en local** sur un ordinateur Windows, puis depuis les tablettes du Wi-Fi. Gratuit, sans hébergeur, sans nom de domaine.
2. **Partie B — déployer chez un hébergeur** quand tout fonctionne. LWS en priorité, avec des alternatives gratuites et payantes.

Les commandes se tapent dans **PowerShell** sous Windows, et dans la **fenêtre SSH** pour un serveur Linux. Chaque bloc se copie-colle tel quel ; seules les valeurs signalées (adresse IP, domaine, mots de passe) sont à remplacer.

> **Rappel du fonctionnement**
>
> - **Adresse** : une seule adresse web sert à la fois l'application et le serveur.
> - **Installation** : sur les tablettes, la caisse et le téléphone du gérant, l'application s'installe depuis Chrome ou Edge (« Installer l'application »), sans Play Store.
> - **Sans internet**, tout continue : commandes, caisse, stock. Tout est envoyé au serveur au retour du réseau.
> - **Comptes** : seul l'administrateur crée, modifie ou supprime un compte. Chaque employé a un code personnel de **6 à 10 chiffres**.

---

# PARTIE A — Tester en local (Windows)

Durée : environ 1 h la première fois. Il faut un PC Windows 10 ou 11 avec 8 Go de mémoire et les droits administrateur.

## A1. Installer les outils (une seule fois)

Ouvrez **PowerShell en administrateur** (clic droit sur Démarrer → **Terminal (administrateur)**) :

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
winget install --id Google.Chrome -e --accept-source-agreements --accept-package-agreements
New-Item -ItemType Directory -Force C:\src | Out-Null
git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";C:\src\flutter\bin", "User")
```

**Base de données : XAMPP** (gratuit ; contient MariaDB, compatible MySQL) :

1. Téléchargez XAMPP pour Windows sur <https://www.apachefriends.org/fr/download.html>.
2. Installez-le dans `C:\xampp`. Seuls les composants **MySQL** et **phpMyAdmin** sont nécessaires.

> Vous préférez MySQL 8 d'Oracle ? <https://dev.mysql.com/downloads/installer/> convient aussi. Remplacez alors `C:\xampp\mysql\bin\mysql.exe` par le chemin de `mysql.exe` de MySQL.

**Fermez puis rouvrez PowerShell**, puis vérifiez :

```powershell
git --version
node --version
flutter --version
```

`node` doit afficher **v20** ou plus récent.

## A2. Récupérer le code et construire l'application

```powershell
cd C:\src
git clone https://github.com/Levi0116/Cr-a-Affiches-.git amani
cd C:\src\amani
git checkout ccr-7324c1b1-dnzjuz
cd gestion_restaurant
flutter pub get
flutter test
flutter build web --release --no-web-resources-cdn --dart-define=SERVEUR=true
node outils\generer-sw.mjs
```

- `flutter test` doit afficher **All tests passed!**
- `--dart-define=SERVEUR=true` relie l'application au serveur. Sans cette option, l'application démarre en mode démonstration, avec des données fictives.
- `generer-sw.mjs` prépare la copie hors ligne de l'application. À relancer après chaque `flutter build web`.

## A3. Démarrer la base et la préparer

1. Ouvrez le **XAMPP Control Panel** (menu Démarrer).
2. Sur la ligne **MySQL**, cliquez sur **Start**. La ligne passe au vert ; inutile de démarrer Apache.
3. Dans PowerShell, créez la base, la base de test et un utilisateur dédié :

```powershell
$MYSQL = "C:\xampp\mysql\bin\mysql.exe"
& $MYSQL -u root -e "CREATE DATABASE IF NOT EXISTS amani CHARACTER SET utf8mb4; CREATE DATABASE IF NOT EXISTS amani_test CHARACTER SET utf8mb4; CREATE USER IF NOT EXISTS 'amani'@'localhost' IDENTIFIED BY 'amani-local'; GRANT ALL ON amani.* TO 'amani'@'localhost'; GRANT ALL ON amani_test.* TO 'amani'@'localhost'; FLUSH PRIVILEGES;"
```

XAMPP n'a pas de mot de passe root au départ : c'est normal pour un test local. Ne jamais le faire sur un serveur en ligne.

## A4. Configurer et lancer le serveur

```powershell
cd C:\src\amani\gestion_restaurant\serveur
npm install
$SECRET = node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
@"
PORT=3000
HOTE=0.0.0.0
MYSQL_HOTE=127.0.0.1
MYSQL_PORT=3306
MYSQL_BASE=amani
MYSQL_UTILISATEUR=amani
MYSQL_MOT_DE_PASSE=amani-local
SECRET_SESSIONS=$SECRET
DUREE_SESSION_H=12
DOSSIER_PWA=../build/web
"@ | Set-Content -Encoding ascii .env
```

**Vérifier le serveur** (facultatif mais conseillé) : 11 tests sur la base `amani_test`.

```powershell
$env:MYSQL_MOT_DE_PASSE = "amani-local"; npm test; Remove-Item Env:\MYSQL_MOT_DE_PASSE
```

Résultat attendu : `# pass 11` et `# fail 0`.

**Créer le restaurant et votre compte administrateur.** Choisissez un code de 6 à 10 chiffres : `482615` est un exemple.

```powershell
npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --admin "Patron" --pin 482615 --telephone "+226 65 91 11 76"
```

Le script affiche un **code de liaison de 8 caractères**, valable **15 minutes**. Notez-le.

**Démarrer le serveur :**

```powershell
npm start
```

Le serveur affiche `Serveur Amani prêt sur http://localhost:3000`. **Laissez cette fenêtre ouverte** : fermer la fenêtre ou taper `Ctrl+C` arrête le serveur.

> Le code a expiré ? Dans une **autre** fenêtre PowerShell : `cd C:\src\amani\gestion_restaurant\serveur` puis `npm run code-liaison -- --id chez-amani`.

## A5. Tester sur l'ordinateur lui-même

1. Ouvrez Chrome sur **<http://localhost:3000>**. L'écran **« Lier cet appareil »** apparaît.
2. Tapez le code de liaison, puis connectez-vous en **Patron** avec votre code et la touche ✓.
3. **Installer comme une application** : icône **Installer** à droite de la barre d'adresse de Chrome. L'application **Chez les Amani** s'ouvre dans sa propre fenêtre.
4. **Administration → Comptes de l'équipe** : créez une serveuse et un caissier, avec des codes de 6 chiffres ou plus.
5. **Tables et zones**, **Menu**, **Stock** : saisissez quelques tables et articles.

**Test hors ligne :**

1. Dans la fenêtre du serveur, tapez `Ctrl+C` : le serveur est arrêté, comme si internet était coupé.
2. Dans l'application, l'indicateur passe à **« Hors ligne »**. Prenez une commande, encaissez : tout fonctionne. L'indicateur montre « N en attente ».
3. Fermez puis rouvrez l'application installée : elle redémarre quand même, et on peut se connecter.
4. Relancez le serveur avec `npm start`. Après quelques secondes, l'indicateur repasse à **« En ligne »** et les actions en attente sont envoyées.

## A6. Tester depuis les tablettes (même Wi-Fi)

1. Ouvrez le port 3000 sur le **réseau privé** de l'ordinateur (PowerShell administrateur) :

```powershell
New-NetFirewallRule -DisplayName "Amani test local" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow -Profile Private
ipconfig | Select-String "IPv4"
```

2. Notez l'adresse IPv4 affichée, par exemple `192.168.1.20`. Le Wi-Fi de l'ordinateur doit être en profil **Privé** : Paramètres → Réseau → propriétés du Wi-Fi → **Privé**.
3. Sur la tablette, connectée au même Wi-Fi, ouvrez Chrome sur **`http://192.168.1.20:3000`** (votre adresse).
4. Sur l'ordinateur, en Patron : **Administration → Appareils → Lier un appareil**, type **Tablette**. Sur la tablette, tapez ou scannez le code.
5. Connectez-vous avec le compte serveuse, prenez une commande : elle apparaît à la caisse en quelques secondes.

> **Limite du test en Wi-Fi local :** sans HTTPS, Chrome n'autorise pas l'installation de l'application sur la tablette, ni son démarrage sans réseau. Tout le reste fonctionne : commandes, synchronisation, coupure pendant l'utilisation.
>
> Pour tester **quand même** l'installation sur une tablette (test uniquement) :
>
> 1. Ouvrez `chrome://flags/#unsafely-treat-insecure-origin-as-secure`.
> 2. Ajoutez `http://192.168.1.20:3000`, mettez **Enabled**, puis **Relaunch**.
> 3. Annulez ce réglage après les essais.
>
> En production (partie B), le HTTPS règle cela pour tout le monde.

## A7. Liste de contrôle avant de déployer

- [ ] Liaison d'un appareil par code et par QR code.
- [ ] Connexion de chaque rôle ; après 5 codes faux, le compte est bloqué 15 minutes.
- [ ] Seul l'administrateur crée, modifie ou supprime un compte ; `123456` et `111111` sont refusés.
- [ ] Commande sur tablette, puis visible à la caisse ; le stock baisse.
- [ ] Facture, encaissement, monnaie, impression du ticket sur l'imprimante 80 mm.
- [ ] Coupure du serveur pendant le service, puis reprise sans perte ; le stock est juste si deux appareils ont vendu hors ligne.
- [ ] Clôture de caisse et rapport du jour.

La liste complète se trouve dans **[RECETTE.md](RECETTE.md)**. Quand tout est coché, passez à la partie B. Les données de test restent sur votre PC : la production démarre avec une base neuve.

---

# PARTIE B — Déployer chez un hébergeur

> **Vous avez pris LWS ?** Suivez directement le guide détaillé **[HEBERGEMENT_LWS.md](HEBERGEMENT_LWS.md)** : identification de l'offre, zone DNS, VPS ou cPanel, base de données, sauvegardes.

## B1. Choisir l'hébergement

Deux façons d'héberger le serveur Node.js :

- **VPS** (serveur privé) : vous avez la main sur toute la machine. Un script fourni installe tout en une commande. **C'est la solution recommandée.**
- **Hébergement cPanel avec « Setup Node.js App »** : pas de serveur à administrer, tout se fait par une interface web. Plus simple, mais plus limité.

Prix relevés en novembre 2026 (HT, TVA 20 % en plus pour un particulier en France). Ils changent souvent : **vérifiez sur le site avant de commander.**

### ⭐ Notre préférence : LWS (hébergeur français, support en français)

| Offre LWS | Prix indicatif | Usage |
|---|---|---|
| **VPS Linux LC1** | ≈ 2,99 € HT / mois | Démarrage, petit restaurant. Le moins cher. |
| **VPS Linux LC2** (4 Go, 40 Go) — **conseillé** | ≈ 5,99 € HT / mois (≈ 4 700 F CFA TTC) | Confortable pour toute l'équipe, plusieurs tablettes. |
| Hébergement **cPanel L** (ou supérieur) avec « Setup Node.js App » | Voir <https://www.lws.fr> → Hébergement web | Sans administration système ; voir la limite ci-dessous. |
| Nom de domaine (`.com`, `.fr`…) | Quelques euros par an — <https://www.lws.fr> → Noms de domaine | Adresse propre, par exemple `chezamani.com`. |

- Offres VPS : <https://www.lws.fr> → menu **Serveurs VPS**. À la commande, choisissez **Ubuntu 24.04** et le centre de données en **France**.
- LWS indique que l'outil Node.js est inclus dans ses formules **cPanel L, XL, 2XL, 3XL et CloudCP**. Le support LWS recommande toutefois un **VPS** pour une application Node.js avec base de données en usage permanent. → **Choisissez un VPS LWS (LC2) si possible.**
- Les VPS LWS d'entrée de gamme sont des conteneurs. Si le pare-feu de la machine n'est pas disponible, le script d'installation vous le signale. Activez alors le pare-feu dans l'**espace client LWS** (ports 22, 80 et 443).

### Autres hébergeurs payants

| Offre | Prix indicatif | Pour / contre |
|---|---|---|
| **Contabo Cloud VPS 10** (4 cœurs, 8 Go) — <https://contabo.com/fr/vps/> | ≈ 4,40 à 5,50 € / mois | Beaucoup de puissance pour le prix ; support plus lent, renouvellement plus cher |
| **Hetzner Cloud CX23** (2 cœurs, 4 Go) — <https://www.hetzner.com/cloud> | ≈ 5,50 à 6 € / mois | Très fiable ; parfois indisponible à la commande |
| **OVHcloud VPS-1** — <https://www.ovhcloud.com/fr/vps/> | ≈ 3,81 € HT / mois la 1re année, plus cher au renouvellement | Français, très connu ; prix de renouvellement à vérifier |

### Alternatives gratuites

| Offre | Ce qu'on obtient | Limites |
|---|---|---|
| **Oracle Cloud « Always Free »** — <https://www.oracle.com/cloud/free/> | Un vrai VPS (ARM, environ 2 cœurs et 12 Go) : **le même script d'installation fonctionne** | Carte bancaire demandée à l'inscription ; limites réduites en 2026 ; machine parfois récupérée si elle est inactive. Bien pour essayer, risqué pour l'exploitation. |
| **alwaysdata (offre gratuite)** — <https://www.alwaysdata.com/fr/> | Hébergement français avec Node.js et MariaDB, sans serveur à administrer (même principe que la voie cPanel, § B4) | Petite mémoire et espace limité (environ 1 Go selon les sources ; vérifiez sur leur site). Suffisant pour une démo ou un très petit usage. |
| **Le PC du restaurant** (comme la partie A) | Gratuit, rapide sur le Wi-Fi | Pas de HTTPS : pas d'installation de l'application ni de démarrage hors ligne sur les tablettes ; pas d'accès à distance pour le patron ; le PC doit rester allumé. À réserver au dépannage. |

**Recommandation :**

1. **LWS VPS LC2** : meilleur compromis, hébergeur français, support en français.
2. Sinon Contabo ou Hetzner.
3. Pour un essai gratuit en ligne : Oracle Always Free.

## B2. Adresse web et HTTPS

L'installation de l'application sur les appareils et le mode hors ligne **exigent HTTPS**, donc un nom de domaine.

- **Payant (conseillé)** : un domaine chez LWS, par exemple `chezamani.com`. Dans l'espace client LWS → **Gestion DNS**, créez un enregistrement **A** qui pointe vers l'adresse IP du VPS.
- **Gratuit** : <https://www.duckdns.org>.
  1. Connectez-vous et créez le sous-domaine `chezamani` : votre adresse sera `chezamani.duckdns.org`.
  2. Mettez l'IP du VPS dans le champ **current ip**, puis cliquez sur **update ip**.

Le certificat HTTPS est **gratuit** (Let's Encrypt, installé par le script).

## B3. Préparer le paquet à envoyer (sur Windows)

Depuis le PC de la partie A :

```powershell
cd C:\src\amani\gestion_restaurant
git pull
flutter build web --release --no-web-resources-cdn --dart-define=SERVEUR=true
node outils\generer-sw.mjs
Remove-Item -Recurse -Force envoi, amani.tgz -ErrorAction SilentlyContinue
New-Item -ItemType Directory envoi | Out-Null
Copy-Item -Recurse build\web envoi\web
robocopy serveur envoi\serveur /E /XD node_modules /XF .env | Out-Null
tar -czf amani.tgz -C envoi .
```

Le fichier **`amani.tgz`** contient l'application et le serveur. Il ne contient ni le fichier `.env` local ni vos données de test.

## B4. Voie 1 — VPS (LWS VPS, Contabo, Hetzner, OVH, Oracle) — recommandée

Remplacez `185.12.34.56` par l'IP de votre VPS (reçue par e-mail avec le mot de passe root).

```powershell
scp C:\src\amani\gestion_restaurant\amani.tgz root@185.12.34.56:/root/
ssh root@185.12.34.56
```

À la première connexion, tapez `yes`, puis le mot de passe.

> Chez Oracle, l'utilisateur est `ubuntu` (et non `root`). Connectez-vous avec la clé SSH créée à l'inscription, puis tapez `sudo -i`.

**Dans la fenêtre SSH**, remplacez le domaine et l'e-mail par les vôtres :

```bash
passwd
mkdir -p /srv/amani && tar -xzf /root/amani.tgz -C /srv/amani
bash /srv/amani/serveur/deploiement/installer-serveur.sh chezamani.com votre@email.com
bash /srv/amani/serveur/deploiement/demarrer.sh
```

- `passwd` change le mot de passe root par un mot de passe long, à noter en lieu sûr.
- `installer-serveur.sh` dure environ 5 minutes. Il installe :
  - le pare-feu et la protection contre les essais de mots de passe ;
  - les mises à jour de sécurité automatiques ;
  - Node.js 22, MySQL 8 et Nginx, avec le certificat HTTPS ;
  - la sauvegarde chaque nuit.

  Il génère aussi tous les mots de passe dans `/srv/amani/serveur/.env`.
- `demarrer.sh` doit se terminer par **Serveur en marche.**

**Créer le restaurant** (code administrateur de 6 à 10 chiffres, différent de celui du test) :

```bash
cd /srv/amani/serveur
sudo -u amani npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --admin "Patron" --pin 739264 --telephone "+226 65 91 11 76"
```

Notez le **code de liaison**, puis passez au § B6.

## B5. Voie 2 — cPanel « Setup Node.js App » (LWS cPanel L et plus, ou équivalent)

1. **Base de données** : cPanel → **Bases de données MySQL**.
   - Créez une base (par exemple `cpuser_amani`) et un utilisateur avec un mot de passe long.
   - Ajoutez l'utilisateur à la base avec **tous les privilèges**.
2. **Envoi des fichiers** : cPanel → **Gestionnaire de fichiers**.
   - Créez un dossier `amani` dans votre dossier personnel (pas dans `public_html`).
   - Envoyez `amani.tgz` dedans, puis **Extraire**. Vous obtenez `amani/web` et `amani/serveur`.
3. **Application Node.js** : cPanel → **Setup Node.js App** → **Create**, puis remplissez :

   | Champ | Valeur |
   |---|---|
   | Node.js version | **22** (ou 20) |
   | Application mode | **Production** |
   | Application root | `amani/serveur` |
   | Application URL | votre domaine ou sous-domaine (par exemple `caisse.chezamani.com`) |
   | Application startup file | **`app.cjs`** |

   Ajoutez ces **variables d'environnement** :

   | Variable | Valeur |
   |---|---|
   | `MYSQL_HOTE` | `localhost` |
   | `MYSQL_BASE` | le nom de la base créée à l'étape 1 |
   | `MYSQL_UTILISATEUR` | l'utilisateur créé à l'étape 1 |
   | `MYSQL_MOT_DE_PASSE` | son mot de passe |
   | `SECRET_SESSIONS` | 64 caractères aléatoires (générés sur Windows par `node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"`) |
   | `DOSSIER_PWA` | `../web` |

   Cliquez sur **Create**, puis **Run NPM Install**, puis **Restart**.
4. **Créer le restaurant** : cPanel → **Terminal**.
   - Collez la commande « Enter to the virtual environment » affichée en haut de la page de l'application, puis :

   ```bash
   cd ~/amani/serveur
   npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --admin "Patron" --pin 739264
   ```
5. **HTTPS** : cPanel → **SSL/TLS Status** → **Run AutoSSL**, pour votre domaine.

> Les noms exacts des menus peuvent varier selon l'hébergeur ; aide LWS : <https://help.lwshosting.com/a/1255>.
>
> **Limites de cette voie :**
>
> - pas de script de sauvegarde automatique : utilisez les sauvegardes de l'hébergeur et exportez régulièrement la base depuis **phpMyAdmin** ;
> - l'application peut se mettre en veille après une période sans visite : la première ouverture est alors un peu plus lente.

## B6. Installer l'application sur les appareils

### Téléphone du gérant (le premier)

1. Ouvrez Chrome sur `https://chezamani.com` (votre adresse).
2. Menu ⋮ → **Installer l'application**.
3. Ouvrez l'application, tapez le **code de liaison**, puis connectez-vous en **Patron**.

Ce téléphone a les **droits administrateur permanents** et lie tous les autres appareils.

### Ordinateur de caisse (Windows)

1. Ouvrez l'adresse dans Chrome ou Edge, puis cliquez sur l'icône **Installer**.
2. Liez l'ordinateur depuis le téléphone du gérant : **Administration → Appareils → Lier un appareil**, type **Caisse**.

Pour imprimer le ticket directement, sans fenêtre de confirmation :

```powershell
$URL = "https://chezamani.com"
$CHROME = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$s = New-Object -ComObject WScript.Shell
foreach ($d in @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Startup"))) {
  $l = $s.CreateShortcut("$d\Caisse Chez les Amani.lnk"); $l.TargetPath = $CHROME
  $l.Arguments = "--kiosk-printing --app=$URL"; $l.IconLocation = "$CHROME,0"; $l.Save()
}
powercfg /change standby-timeout-ac 0
```

L'imprimante thermique 80 mm doit être l'**imprimante par défaut** de Windows. Fermez toutes les fenêtres Chrome avant d'ouvrir le raccourci.

### Tablettes des serveuses

Pour chaque tablette :

1. Chrome → menu ⋮ → **Installer l'application**.
2. Depuis le téléphone du gérant : **Lier un appareil** → type **Tablette**.
3. Sur la tablette, scannez le QR code.

Réglages conseillés : mise en veille à 10 minutes, optimisation de batterie désactivée pour Chrome.

## B7. Comptes de l'équipe et données

**Administration → Comptes de l'équipe → Nouveau compte** : nom, rôle, code de 6 à 10 chiffres saisi deux fois.

- Les codes trop simples sont refusés, et deux employés ne peuvent pas avoir le même code.
- Après **5 codes faux**, le compte est bloqué 15 minutes.
- **Modifier** et **Supprimer** sont réservés à l'administrateur connecté en ligne. Un compte supprimé ne peut plus se connecter ; son nom reste dans l'historique.

Saisissez ensuite les **tables et zones**, le **menu** (plats ivoiriens, grillades, boissons), le **stock** de départ et les **paramètres** (adresse, texte du ticket).

## B8. Sauvegardes

**VPS (voie 1)** : sauvegarde automatique chaque nuit à 3 h, dans `/srv/amani/sauvegardes`, gardée 14 jours.

Copie chaque semaine sur le PC Windows :

```powershell
New-Item -ItemType Directory -Force C:\amani-sauvegardes | Out-Null
scp "root@185.12.34.56:/srv/amani/sauvegardes/*.sql.gz" C:\amani-sauvegardes\
```

Restauration (en cas de catastrophe uniquement), sur le serveur :

```bash
gunzip -c /srv/amani/sauvegardes/amani-AAAA-MM-JJ-0300.sql.gz | mysql amani
sudo -u amani pm2 reload amani
```

**cPanel (voie 2)** : utilisez les sauvegardes de l'hébergeur, plus un export hebdomadaire depuis **phpMyAdmin** (onglet Exporter).

## B9. Mettre à jour la plateforme

1. Tester d'abord en local (partie A).
2. Refaire le paquet (§ B3).
3. Le matin, hors service, envoyer la mise à jour.

**VPS :**

```powershell
scp C:\src\amani\gestion_restaurant\amani.tgz root@185.12.34.56:/root/
ssh root@185.12.34.56 "tar -xzf /root/amani.tgz -C /srv/amani && bash /srv/amani/serveur/deploiement/demarrer.sh"
```

**cPanel** : envoyez et extrayez `amani.tgz` dans `amani/` (remplacer les fichiers), puis **Run NPM Install** et **Restart** dans « Setup Node.js App ».

La base et le fichier `.env` ne sont jamais écrasés. Les appareils chargent la nouvelle version au prochain démarrage de l'application.

---

## Sécurité en place

| Protection | Détail |
|---|---|
| Connexions chiffrées | HTTPS (Let's Encrypt), HSTS |
| Codes des employés | 6 à 10 chiffres, jamais stockés en clair (PBKDF2-SHA256 salé, 120 000 itérations), blocage après 5 erreurs |
| Comptes | Création, modification et suppression **uniquement** par l'administrateur, vérifiées par le serveur ; au moins un administrateur garanti |
| Appareils | Liaison par code à usage unique (15 min) ; jeton stocké sous forme d'empreinte ; retrait à distance (l'appareil efface ses données) |
| Droits | Chaque écriture est vérifiée par le serveur : une serveuse ne change pas un prix ; une facture réglée ne change plus ; rien n'est supprimé |
| Serveur (VPS) | Pare-feu (22, 80, 443), fail2ban, mises à jour de sécurité automatiques, MySQL fermé à internet, application sans droits root, limitation des requêtes, en-têtes de sécurité (CSP) |
| Traçabilité | Journal d'audit (comptes, appareils, codes bloqués, validations) |

**À faire de votre côté :**

- un mot de passe root long ;
- un code administrateur connu de vous seul ;
- une copie des sauvegardes chaque semaine ;
- retirer sans attendre tout appareil perdu.

## Dépannage

| Problème | Solution |
|---|---|
| Local : `npm start` affiche « ECONNREFUSED 127.0.0.1:3306 » | MySQL n'est pas démarré : XAMPP Control Panel → MySQL → **Start** |
| Local : « Access denied for user 'amani' » | Refaites la commande de l'étape A3 ; vérifiez `MYSQL_MOT_DE_PASSE` dans `.env` |
| Local : la tablette n'ouvre pas `http://192.168…:3000` | Même Wi-Fi ? Profil réseau **Privé** ? Règle de pare-feu de l'étape A6 ? Bonne adresse dans `ipconfig` ? |
| L'application montre des données fictives | Construite sans `--dart-define=SERVEUR=true` : refaites `flutter build web …` |
| Pas de bouton « Installer » dans Chrome | Il faut **https://** (ou `localhost` sur le PC lui-même) |
| VPS : `certbot` échoue | Le domaine ne pointe pas encore vers l'IP (DNS ou DuckDNS), ou le port 80 est fermé dans le pare-feu de l'hébergeur |
| VPS : « 502 Bad Gateway » | `sudo -u amani pm2 logs amani --lines 50`, puis `bash /srv/amani/serveur/deploiement/demarrer.sh` |
| cPanel : l'application ne démarre pas | « Setup Node.js App » : startup file = `app.cjs`, version de Node 20 ou plus, variables d'environnement bien remplies ; consultez le fichier `stderr.log` dans `amani/serveur` |
| « Code inconnu, expiré ou déjà utilisé » | Nouveau code depuis le téléphone du gérant, ou `npm run code-liaison -- --id chez-amani` sur le serveur |
| Téléphone du gérant perdu | Sur le serveur : `npm run code-liaison -- --id chez-amani`, liez le nouveau téléphone, puis retirez l'ancien dans **Appareils** |
| « Gestion des comptes indisponible hors ligne » | Reconnectez-vous en administrateur quand internet est revenu |

---

Sources des prix et informations (novembre 2026) :

- LWS :
  - [comparatif VPS (Hackceleration)](https://hackceleration.com/fr/labs/pas-cher/serveur-vps) ;
  - [LWS LC2 (WHTop)](https://www.whtop.com/fr/plans/lws.fr/133041) ;
  - [test VPS LWS (Next)](https://next.ink/224199/test-vps-pas-cher-5-euros-lws-utilise-la-virtualisation-lxcfs-et-impose-des-bridages/) ;
  - [Node.js sur cPanel LWS](https://help.lwshosting.com/a/1255).
- Autres hébergeurs :
  - [Contabo (PricingSaaS)](https://pricingsaas.com/companies/contabo) ;
  - [Hetzner (Bitdoze)](https://www.bitdoze.com/hetzner-cloud-cost-optimized-plans/) ;
  - [OVHcloud (OuiHeberg)](https://www.ouiheberg.com/en/blog/cheap-linux-vps).
- Offres gratuites :
  - [Oracle Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm) ;
  - [alwaysdata (offres)](https://help.alwaysdata.com/en/accounts/billing/choose-its-paas) et [freetier.co](https://freetier.co/directory/products/alwaysdata).
