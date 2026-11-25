# Installation chez LWS — Restaurant Chez les Amani

**Solution retenue :** votre hébergement **Perso** garde le domaine `restaurant-chez-amani.com` et les e-mails. Un **VPS LWS** fait tourner l'application à l'adresse :

## 👉 `https://app.restaurant-chez-amani.com`

Il vous faut :

- le fichier **`amani.tgz`** (fourni : l'application déjà construite) ;
- un **PC Windows 10 ou 11**, sans rien à installer ;
- environ **1 heure**.

Seules **3 valeurs** sont à remplacer dans les commandes : l'**adresse IP** du VPS, son **port SSH** et votre **e-mail**. Tout le reste est déjà rempli.

---

## Étape 1 — Commander le VPS chez LWS

1. Connectez-vous sur <https://panel.lws.fr>.
2. **Commander** → **Serveurs VPS** → **VPS Linux**.
3. Choisissez :
   - **Modèle : LC2** (conseillé, environ 5,99 € HT par mois) ou **LC1** (environ 2,99 € HT par mois, suffisant pour démarrer) ;
   - **Système : Ubuntu 24.04** ;
   - **Emplacement : France**.
4. Payez. LWS envoie un e-mail quand le VPS est prêt (en général en quelques minutes).

## Étape 2 — Noter les accès du VPS

Dans l'espace client → **votre VPS** (ou dans l'e-mail de LWS), notez :

| Information | Exemple | Votre valeur |
|---|---|---|
| Adresse IP | `185.12.34.56` | ............................ |
| Port SSH | `22` (parfois un autre, ex. `2123`) | ............................ |
| Mot de passe root | (fourni par LWS) | ............................ |

## Étape 3 — Créer l'adresse `app.restaurant-chez-amani.com`

1. Espace client LWS → **Mes domaines** → **restaurant-chez-amani.com** → **Zone DNS** (ou « Gestion DNS »).
2. **Ajouter un enregistrement** :

   | Type | Nom | Valeur | TTL |
   |---|---|---|---|
   | **A** | `app` | l'adresse IP du VPS | 3600 |

3. Enregistrez. **Ne modifiez pas les autres lignes** : elles font fonctionner votre site actuel et vos e-mails.

**Vérification** (après 5 à 30 minutes). Sur le PC : menu Démarrer → tapez **PowerShell** → ouvrez-le, puis :

```powershell
nslookup app.restaurant-chez-amani.com
```

✅ L'adresse IP du VPS doit apparaître dans la réponse. Sinon, attendez encore un peu et recommencez. **Ne passez pas à l'étape 5 avant.**

## Étape 4 — Envoyer l'application sur le VPS

Enregistrez **`amani.tgz`** dans votre dossier **Téléchargements**. Dans **PowerShell**, remplacez l'IP et le port par les vôtres sur les deux premières lignes, puis copiez-collez tout le bloc :

```powershell
$IP   = "185.12.34.56"
$PORT = "22"
scp -P $PORT "$env:USERPROFILE\Downloads\amani.tgz" "root@${IP}:/root/"
ssh -p $PORT root@$IP
```

Ce qui se passe :

1. À la question `Are you sure you want to continue connecting`, tapez **`yes`**, puis Entrée.
2. Tapez le **mot de passe root** quand il est demandé (deux fois : une pour l'envoi, une pour la connexion). **Rien ne s'affiche pendant la frappe**, c'est normal.

✅ Vous êtes connecté au VPS quand la ligne commence par `root@...:~#`.

## Étape 5 — Installer le serveur (une seule commande)

**Dans la même fenêtre** (connectée au VPS) :

**a)** Changez d'abord le mot de passe root. Choisissez-en un long et notez-le :

```bash
passwd
```

**b)** Installez tout. Remplacez seulement **votre@email.com** (il sert aux alertes du certificat HTTPS) :

```bash
mkdir -p /srv/amani && tar -xzf /root/amani.tgz -C /srv/amani
bash /srv/amani/serveur/deploiement/installer-serveur.sh app.restaurant-chez-amani.com votre@email.com
```

L'installation dure environ 5 minutes. Elle met en place :

- le pare-feu et la protection contre les attaques ;
- les mises à jour de sécurité automatiques ;
- Node.js, MySQL (la **base de données**, sur le VPS) et Nginx ;
- le **certificat HTTPS gratuit** ;
- la **sauvegarde de la base chaque nuit**.

Elle génère aussi tous les mots de passe internes.

**c)** Démarrez l'application :

```bash
bash /srv/amani/serveur/deploiement/demarrer.sh
```

✅ La dernière ligne doit afficher **`Serveur en marche.`**

## Étape 6 — Créer le restaurant et votre compte administrateur

Choisissez **votre code administrateur** : 6 à 10 chiffres, connu de vous seul. Pas de suite comme `123456`, pas de répétition comme `111111`. Remplacez `739264` par ce code :

```bash
cd /srv/amani/serveur
sudo -u amani npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --admin "Patron" --pin 739264 --telephone "+226 65 91 11 76"
```

✅ Le script affiche un **code de liaison de 8 caractères**, valable **15 minutes**. Passez tout de suite à l'étape 7.

> Le code a expiré ? Toujours dans la fenêtre du VPS :
>
> ```bash
> cd /srv/amani/serveur && sudo -u amani npm run code-liaison -- --id chez-amani
> ```

## Étape 7 — Installer l'application sur les appareils

### 1. Téléphone du gérant (le premier)

1. Ouvrez **Chrome** → **`https://app.restaurant-chez-amani.com`**. Le **cadenas** 🔒 doit être affiché.
2. Menu **⋮** → **Installer l'application**. L'icône **Chez les Amani** apparaît sur l'écran d'accueil.
3. Ouvrez-la, tapez le **code de liaison** de l'étape 6, puis touchez **Patron** → votre code → **✓**.

### 2. Ordinateur de caisse

1. Chrome ou Edge → `https://app.restaurant-chez-amani.com` → icône **Installer** à droite de la barre d'adresse.
2. Sur le téléphone du gérant : **Administration → Appareils → Lier un appareil** → type **Caisse**. Tapez le code affiché sur l'ordinateur.
3. Ticket imprimé directement (imprimante 80 mm réglée comme imprimante **par défaut** de Windows). Dans PowerShell, sur l'ordinateur de caisse :

```powershell
$URL = "https://app.restaurant-chez-amani.com"
$CHROME = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$s = New-Object -ComObject WScript.Shell
foreach ($d in @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Startup"))) {
  $l = $s.CreateShortcut("$d\Caisse Chez les Amani.lnk"); $l.TargetPath = $CHROME
  $l.Arguments = "--kiosk-printing --app=$URL"; $l.IconLocation = "$CHROME,0"; $l.Save()
}
powercfg /change standby-timeout-ac 0
```

Utilisez ensuite le raccourci **Caisse Chez les Amani** du bureau, après avoir fermé toutes les fenêtres Chrome.

### 3. Tablettes des serveuses

Pour chaque tablette :

1. Chrome → l'adresse → **⋮ → Installer l'application**.
2. Téléphone du gérant → **Lier un appareil** → type **Tablette**.
3. Sur la tablette, **scannez le QR code**.

### 4. Comptes et données

- **Administration → Comptes de l'équipe → Nouveau compte** : un code personnel de 6 à 10 chiffres par employé.
- Puis **Tables et zones**, **Menu**, **Stock**, **Paramètres** (adresse, texte du ticket).

---

## Vérifications finales

- [ ] `https://app.restaurant-chez-amani.com` affiche le cadenas 🔒.
- [ ] `https://app.restaurant-chez-amani.com/api/sante` affiche `{"ok":true,...}`.
- [ ] Une commande passée sur une tablette apparaît à la caisse en quelques secondes.
- [ ] Wi-Fi coupé sur une tablette : elle continue ; tout se synchronise au retour du réseau.
- [ ] Mot de passe root et code administrateur notés en lieu sûr.

---

## Sauvegardes de la base de données

- **Automatique** : chaque nuit à 3 h, sur le VPS, gardée 14 jours.
- **Copie sur votre PC** (une fois par semaine). Dans PowerShell, avec votre IP et votre port :

```powershell
$IP = "185.12.34.56"; $PORT = "22"
New-Item -ItemType Directory -Force C:\amani-sauvegardes | Out-Null
scp -P $PORT "root@${IP}:/srv/amani/sauvegardes/*.sql.gz" C:\amani-sauvegardes\
```

## Mises à jour

Quand je vous fournis un nouveau **`amani.tgz`** : le matin, hors service, mettez-le dans Téléchargements, puis :

```powershell
$IP = "185.12.34.56"; $PORT = "22"
scp -P $PORT "$env:USERPROFILE\Downloads\amani.tgz" "root@${IP}:/root/"
ssh -p $PORT root@$IP "tar -xzf /root/amani.tgz -C /srv/amani && bash /srv/amani/serveur/deploiement/demarrer.sh"
```

Vos données et vos mots de passe ne sont jamais écrasés.

---

## En cas de problème

| Ce que vous voyez | Que faire |
|---|---|
| `ssh` ou `scp` : « Connection refused » ou « timed out » | Vérifiez l'IP et le **port** (espace client LWS → votre VPS) |
| `nslookup` ne montre pas l'IP du VPS | Zone DNS : vérifiez la ligne **A**, nom `app`, valeur = IP ; attendez jusqu'à quelques heures |
| L'installation s'arrête sur une erreur `certbot` | L'adresse ne pointe pas encore vers le VPS : attendez que `nslookup` soit bon, puis relancez la commande de l'étape 5 b (sans risque) |
| Message « pare-feu ufw indisponible » | Activez le pare-feu dans l'espace client LWS (votre port SSH, 80 et 443) |
| La page affiche « 502 Bad Gateway » | Dans la fenêtre du VPS : `bash /srv/amani/serveur/deploiement/demarrer.sh` |
| « Code inconnu, expiré ou déjà utilisé » | Nouveau code (encadré de l'étape 6) |

**Pour tout autre message : faites une capture d'écran de la fenêtre et envoyez-la-moi.**
