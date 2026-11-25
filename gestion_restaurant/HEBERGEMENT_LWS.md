# Héberger la plateforme chez LWS — guide pas à pas

**Restaurant Chez les Amani · version 2**

Ce guide explique comment mettre en ligne l'application chez **LWS**, la relier à votre **nom de domaine** et y **stocker la base de données**. Il complète [MISE_EN_SERVICE.md](MISE_EN_SERVICE.md), dont la partie A (test en local) est conseillée avant de commencer.

> Les menus de l'espace client LWS peuvent changer légèrement de nom. En cas de doute, le support LWS (chat ou ticket depuis l'espace client) répond en français.

---

## 1. Ce qu'il faut héberger

| Élément | Technologie | Où il tourne chez LWS |
|---|---|---|
| Application (front-end) | PWA Flutter : fichiers web dans le dossier `web/` | Servie par le serveur Node.js, à la même adresse |
| Serveur (back-end) | Node.js 22 + Express (dossier `serveur/`) | Sur votre VPS LWS, ou dans « Setup Node.js App » (cPanel) |
| Base de données | MySQL 8 ou MariaDB | **Sur le même serveur LWS**, jamais ouverte sur internet |
| Adresse web | Votre nom de domaine + certificat HTTPS gratuit | Zone DNS de LWS |

**Chemin d'une requête :**

```
Tablette / caisse / téléphone
        │  https://chezamani.com
        ▼
Nom de domaine (zone DNS LWS) ──► serveur LWS
                                   ├─ Nginx (HTTPS) ou Passenger (cPanel)
                                   ├─ Node.js : application + API /api
                                   └─ MySQL : base « amani » (locale)
```

---

## 2. Étape 0 — Identifier votre offre LWS

Dans l'**espace client LWS** (<https://panel.lws.fr>), regardez le nom de votre service :

| Votre offre | Peut héberger l'application ? | Suivez |
|---|---|---|
| **VPS** (VPS Linux LC1, LC2, VPS S/M/L, KVM…) | ✅ Oui, la meilleure solution | **Voie A** (§ 4) |
| **Hébergement web cPanel L, XL, 2XL, 3XL ou CloudCP** | ✅ Oui, avec l'outil « Setup Node.js App » | **Voie B** (§ 5) |
| Hébergement **Perso, Starter, cPanel S ou M** (sans Node.js) | ❌ Non : ces formules n'exécutent pas Node.js | Demandez au support LWS de **passer à un VPS ou à cPanel L** (en gardant votre domaine) |
| **Nom de domaine seul** | ❌ Il faut aussi un VPS ou un cPanel L | Commandez un **VPS LC2** et reliez-y le domaine (§ 3) |

> Un nom de domaine est souvent **offert la première année** avec un hébergement LWS. Vérifiez dans l'espace client s'il apparaît dans vos services.

---

## 3. Préparer l'application sur votre PC Windows

Si ce n'est pas déjà fait, installez les outils et récupérez le code (guide MISE_EN_SERVICE, § A1 et A2). Puis, dans **PowerShell** :

```powershell
cd C:\src\amani\gestion_restaurant
git pull
flutter pub get
flutter build web --release --no-web-resources-cdn --dart-define=SERVEUR=true
node outils\generer-sw.mjs
Remove-Item -Recurse -Force envoi, amani.tgz -ErrorAction SilentlyContinue
New-Item -ItemType Directory envoi | Out-Null
Copy-Item -Recurse build\web envoi\web
robocopy serveur envoi\serveur /E /XD node_modules /XF .env | Out-Null
tar -czf amani.tgz -C envoi .
```

Vous obtenez **`amani.tgz`**, qui contient `web/` (l'application) et `serveur/` (le back-end). Il ne contient aucun mot de passe : ceux-ci sont créés sur le serveur.

Choisissez dès maintenant :

- votre **adresse** : le domaine principal (`chezamani.com`), ou un sous-domaine (`app.chezamani.com`) si le domaine sert déjà à un site vitrine ;
- votre **code administrateur** : 6 à 10 chiffres, pas de suite comme `123456`, pas de répétition comme `111111`.

---

## 4. Voie A — VPS LWS (recommandée)

### A.1 Préparer le VPS dans l'espace client

1. **Espace client LWS → votre VPS**. Notez :
   - l'**adresse IP** (par exemple `185.12.34.56`) ;
   - le **mot de passe root** ;
   - le **port SSH**. C'est souvent `22`, mais LWS affiche parfois un autre port (par exemple `2123`) : utilisez celui indiqué.
2. Si le système n'est pas **Ubuntu 24.04** (ou 22.04), utilisez **Réinstaller** dans le panneau du VPS et choisissez **Ubuntu 24.04**. Cela efface le VPS, ce qui ne pose pas de problème s'il est neuf.

### A.2 Relier le nom de domaine au VPS (zone DNS)

**Espace client LWS → votre domaine → Zone DNS** (ou « Gestion DNS »). Modifiez ou créez ces enregistrements :

| Type | Nom (sous-domaine) | Valeur | TTL |
|---|---|---|---|
| **A** | `@` (le domaine lui-même) | IP du VPS, ex. `185.12.34.56` | 3600 |
| **A** | `www` | IP du VPS | 3600 |

- Si vous préférez un sous-domaine, créez seulement **A**, nom `app`, valeur = IP du VPS.
- Supprimez les anciens enregistrements **A** ou **AAAA** du même nom qui pointeraient ailleurs (par exemple vers un hébergement par défaut).
- La prise en compte prend de quelques minutes à quelques heures (48 h au maximum).

**Vérifier depuis Windows** :

```powershell
nslookup chezamani.com
nslookup www.chezamani.com
```

La réponse doit afficher l'IP de votre VPS. **Attendez ce résultat avant l'étape A.4** : le certificat HTTPS en a besoin.

### A.3 Envoyer l'application et se connecter

Remplacez l'IP et le port (`-P` majuscule pour `scp`, `-p` minuscule pour `ssh`) :

```powershell
scp -P 22 C:\src\amani\gestion_restaurant\amani.tgz root@185.12.34.56:/root/
ssh -p 22 root@185.12.34.56
```

À la première connexion, tapez `yes`, puis le mot de passe root (rien ne s'affiche pendant la frappe, c'est normal).

### A.4 Installer le serveur, la base et le HTTPS (une commande)

**Dans la fenêtre SSH.** Mettez vos adresses (séparées par une virgule, sans espace) et votre e-mail :

```bash
passwd
mkdir -p /srv/amani && tar -xzf /root/amani.tgz -C /srv/amani
bash /srv/amani/serveur/deploiement/installer-serveur.sh chezamani.com,www.chezamani.com votre@email.com
bash /srv/amani/serveur/deploiement/demarrer.sh
```

- `passwd` remplace le mot de passe root par un mot de passe long, à noter en lieu sûr.
- `installer-serveur.sh` dure environ 5 minutes. Il installe et configure :
  - **pare-feu** : il détecte votre port SSH et le laisse ouvert, plus 80 et 443. S'il n'est pas disponible sur votre VPS, le script le dit : activez alors le pare-feu dans l'espace client LWS ;
  - **fail2ban** (blocage des attaques par mot de passe) et **mises à jour de sécurité automatiques** ;
  - **Node.js 22**, **PM2** (redémarrage automatique) et **Nginx** ;
  - **MySQL 8**, avec la base `amani`, un utilisateur dédié aux droits limités et un mot de passe aléatoire ;
  - le **certificat HTTPS gratuit** (Let's Encrypt), renouvelé automatiquement ;
  - la **sauvegarde de la base chaque nuit** à 3 h.
- `demarrer.sh` doit se terminer par **Serveur en marche.**

Ouvrez `https://chezamani.com` : le **cadenas** s'affiche, avec l'écran « Lier cet appareil ».

### A.5 Créer le restaurant et votre compte administrateur

```bash
cd /srv/amani/serveur
sudo -u amani npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --admin "Patron" --pin 739264 --telephone "+226 65 91 11 76"
```

Remplacez `739264` par **votre** code. Notez le **code de liaison** affiché (8 caractères, valable 15 minutes), puis passez au § 6.

### A.6 La base de données sur le VPS

| Question | Réponse |
|---|---|
| Où est-elle ? | MySQL 8 sur le VPS lui-même ; fichiers dans `/var/lib/mysql`, base **`amani`** |
| Qui y accède ? | Uniquement le serveur Node.js, depuis la machine elle-même. MySQL n'écoute pas sur internet. |
| Mot de passe | Généré automatiquement : dans `/root/.amani-mysql` et `/srv/amani/serveur/.env` |
| Tables | `documents` (toutes les données du restaurant), `appareils`, `codes_liaison`, `essais_pin`, `lots_appliques`, `restaurants`. Elles sont créées et mises à jour automatiquement (`npm run migrer`). |
| Sauvegardes | Chaque nuit dans `/srv/amani/sauvegardes`, gardées 14 jours |

**Copier les sauvegardes sur votre PC** (à faire chaque semaine) :

```powershell
New-Item -ItemType Directory -Force C:\amani-sauvegardes | Out-Null
scp -P 22 "root@185.12.34.56:/srv/amani/sauvegardes/*.sql.gz" C:\amani-sauvegardes\
```

**Consulter la base avec un logiciel** (facultatif), sans l'ouvrir sur internet :

1. Installez **HeidiSQL** (`winget install --id HeidiSQL.HeidiSQL -e`).
2. Créez une connexion de type **MySQL (SSH tunnel)** :
   - **onglet SSH** : hôte = IP du VPS, port = votre port SSH, utilisateur `root` ;
   - **onglet Paramètres** : hôte `127.0.0.1`, port `3306`, utilisateur `amani`, mot de passe = contenu de `/root/.amani-mysql` (s'affiche avec `cat /root/.amani-mysql` dans SSH).
3. **Ne modifiez pas les données à la main** : passez toujours par l'application, pour garder le journal d'audit et la synchronisation.

**Restaurer une sauvegarde** (en cas de catastrophe uniquement) :

```bash
gunzip -c /srv/amani/sauvegardes/amani-AAAA-MM-JJ-0300.sql.gz | mysql amani
sudo -u amani pm2 reload amani
```

---

## 5. Voie B — Hébergement cPanel LWS (cPanel L ou supérieur)

### B.1 Choisir l'adresse

Le domaine inclus dans l'offre est déjà relié à l'hébergement. Deux choix :

- **Domaine principal** (`chezamani.com`) : rien à créer.
- **Sous-domaine** (`app.chezamani.com`), si le domaine sert déjà à un site : **cPanel → Domaines** (ou « Sous-domaines ») → **Créer** `app`.

Si le domaine est chez LWS mais l'hébergement sur un autre compte, l'enregistrement **A** doit pointer vers l'IP de l'hébergement cPanel (visible dans l'espace client).

### B.2 Créer la base de données

**cPanel → Bases de données MySQL** (ou « Assistant de base de données MySQL ») :

1. **Créer une base** : nom `amani`. cPanel ajoute un préfixe, par exemple `cpuser_amani` : notez le nom complet.
2. **Créer un utilisateur** : `amani` (devient `cpuser_amani`) avec un **mot de passe long** (bouton « Générer »). Notez-le.
3. **Ajouter l'utilisateur à la base** et cocher **Tous les privilèges**.

La base est stockée sur le serveur LWS de votre hébergement et accessible uniquement par votre application (hôte `localhost`). Elle reste consultable dans **cPanel → phpMyAdmin**.

### B.3 Envoyer les fichiers

**cPanel → Gestionnaire de fichiers** :

1. Dans votre dossier personnel (pas dans `public_html`), créez le dossier **`amani`**.
2. Ouvrez-le, cliquez sur **Charger** et envoyez `amani.tgz`.
3. Faites un clic droit sur `amani.tgz` → **Extract**. Vous obtenez `amani/web` et `amani/serveur`.

### B.4 Créer l'application Node.js

**cPanel → Setup Node.js App → Create application** :

| Champ | Valeur |
|---|---|
| Node.js version | **22** (ou 20) |
| Application mode | **Production** |
| Application root | `amani/serveur` |
| Application URL | votre domaine ou sous-domaine |
| Application startup file | **`app.cjs`** |

Ajoutez ensuite ces **variables d'environnement** (bouton « Add variable ») :

| Nom | Valeur |
|---|---|
| `MYSQL_HOTE` | `localhost` |
| `MYSQL_BASE` | nom complet de la base, ex. `cpuser_amani` |
| `MYSQL_UTILISATEUR` | nom complet de l'utilisateur, ex. `cpuser_amani` |
| `MYSQL_MOT_DE_PASSE` | le mot de passe de l'étape B.2 |
| `SECRET_SESSIONS` | 64 caractères aléatoires (voir ci-dessous) |
| `DOSSIER_PWA` | `../web` |

Pour générer `SECRET_SESSIONS` sur votre PC (PowerShell), copiez le résultat de cette commande :

```powershell
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

Cliquez sur **Create**, puis **Run NPM Install**, puis **Restart**.

### B.5 Activer le HTTPS

Dans l'**espace client LWS**, rubrique **Certificat SSL** (ou cPanel → **SSL/TLS Status** → **Run AutoSSL**), activez le certificat **Let's Encrypt gratuit** pour votre domaine (et le sous-domaine `app` si vous en utilisez un).

Ouvrez ensuite `https://votre-adresse` : l'écran « Lier cet appareil » doit s'afficher avec le cadenas.

### B.6 Créer le restaurant

**cPanel → Terminal**. Si le terminal n'apparaît pas, activez l'accès SSH dans l'espace client LWS, ou demandez au support.

1. Collez la commande **« Enter to the virtual environment »** affichée en haut de la page de votre application Node.js.
2. Lancez :

```bash
cd ~/amani/serveur
npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --admin "Patron" --pin 739264 --telephone "+226 65 91 11 76"
```

Notez le **code de liaison**, puis passez au § 6.

### B.7 Sauvegardes en cPanel

- LWS fait ses propres sauvegardes de l'hébergement : consultez la rubrique **Sauvegardes** de l'espace client.
- Chaque semaine, exportez aussi la base vous-même : **cPanel → phpMyAdmin** → choisir la base → **Exporter** → **Exécuter**. Gardez le fichier `.sql` sur votre PC et une clé USB.
- **Restaurer** : phpMyAdmin → la base → **Importer** le fichier `.sql`, puis **Restart** de l'application Node.js.

> **Limites de la voie cPanel** : l'application peut se mettre en veille sans visite (la première ouverture est alors plus lente), et les ressources sont partagées. Si le restaurant tourne à plein régime, passez à un **VPS LWS** : le support peut migrer le domaine.

---

## 6. Mettre en service les appareils

1. **Téléphone du gérant** :
   - Chrome → `https://chezamani.com` → menu ⋮ → **Installer l'application** ;
   - ouvrez-la, tapez le **code de liaison**, puis connectez-vous en **Patron** avec votre code.
2. **Ordinateur de caisse** : ouvrez l'adresse dans Chrome ou Edge → icône **Installer**. Puis, depuis le téléphone du gérant : **Administration → Appareils → Lier un appareil** (type **Caisse**).
3. **Tablettes** : Chrome → **Installer l'application** → liaison par QR code depuis le téléphone du gérant (type **Tablette**).
4. **Comptes de l'équipe** : **Administration → Comptes de l'équipe → Nouveau compte**. Un code de 6 à 10 chiffres par personne.
5. **Données** : tables et zones, menu, stock de départ, paramètres (adresse, texte du ticket).

Le détail (impression directe du ticket, réglages des tablettes) est dans [MISE_EN_SERVICE.md](MISE_EN_SERVICE.md), § B6 et B7.

---

## 7. Vérifications finales

- [ ] `https://chezamani.com` affiche le cadenas, sur PC et sur téléphone.
- [ ] `https://chezamani.com/api/sante` affiche `{"ok":true,...}`.
- [ ] L'application s'installe sur un téléphone Android et sur le PC de caisse.
- [ ] Une commande passée sur une tablette apparaît à la caisse en quelques secondes.
- [ ] En coupant le Wi-Fi d'une tablette, elle continue de fonctionner ; tout se synchronise au retour du réseau.
- [ ] Une sauvegarde existe : VPS : `ls /srv/amani/sauvegardes` le lendemain ; cPanel : export phpMyAdmin.
- [ ] Le mot de passe root (VPS) et le code administrateur sont notés en lieu sûr.

---

## 8. Mettre à jour plus tard

1. Sur le PC : refaire le § 3 (nouveau `amani.tgz`).
2. Le matin, hors service, envoyer la mise à jour :

   - **VPS** :

     ```powershell
     scp -P 22 C:\src\amani\gestion_restaurant\amani.tgz root@185.12.34.56:/root/
     ssh -p 22 root@185.12.34.56 "tar -xzf /root/amani.tgz -C /srv/amani && bash /srv/amani/serveur/deploiement/demarrer.sh"
     ```

   - **cPanel** : envoyer et extraire `amani.tgz` dans `amani/` (remplacer), puis **Run NPM Install** et **Restart**.

La base de données et les mots de passe ne sont jamais écrasés.

---

## 9. Dépannage spécifique LWS

| Problème | Solution |
|---|---|
| `ssh` : « Connection refused » ou délai dépassé | Mauvais port : utilisez celui de l'espace client (`ssh -p PORT`, `scp -P PORT`) ; vérifiez l'IP |
| `nslookup` ne donne pas l'IP du VPS | Zone DNS : enregistrement **A** `@` et `www` vers l'IP ; supprimez les anciens A/AAAA ; attendez la propagation |
| `certbot` échoue pendant l'installation | Le domaine ne pointe pas encore vers le VPS : attendez, puis relancez `installer-serveur.sh` (il peut être relancé sans risque) |
| Le script signale « pare-feu ufw indisponible » | VPS en conteneur : activez le pare-feu dans l'espace client LWS (port SSH, 80, 443) |
| « 502 Bad Gateway » (VPS) | `sudo -u amani pm2 logs amani --lines 50`, puis `bash /srv/amani/serveur/deploiement/demarrer.sh` |
| cPanel : pas d'outil « Setup Node.js App » | Votre formule ne l'inclut pas (seules cPanel L, XL, 2XL, 3XL et CloudCP l'incluent) : passez à cPanel L ou à un VPS |
| cPanel : l'application ne démarre pas | Startup file = `app.cjs` ; version de Node 20 ou plus ; variables bien remplies (nom complet de la base avec préfixe) ; voir `stderr.log` dans `amani/serveur` |
| « Access denied » MySQL (cPanel) | Utilisateur non ajouté à la base, ou préfixe `cpuser_` oublié dans `MYSQL_BASE` ou `MYSQL_UTILISATEUR` |
| Code de liaison expiré | VPS : `cd /srv/amani/serveur && sudo -u amani npm run code-liaison -- --id chez-amani` ; cPanel : même commande dans le Terminal (sans `sudo -u amani`) |

Aide officielle LWS :

- [Node.js sur cPanel](https://help.lwshosting.com/a/1255) ;
- [relier un domaine à un serveur](https://help.lws.net/a/566) ;
- [retrouver les IP de vos services](https://help.lwshosting.com/a/1736) ;
- [VPS Ubuntu LWS](https://www.lws.net/ubuntu-vps).
