# Mise en service — Restaurant Chez les Amani (version 2)

**PWA + serveur Node.js + MySQL, hébergés sur un VPS.** Ce guide part d'un ordinateur Windows et va jusqu'au premier service. Les commandes Windows se tapent dans **PowerShell** ; celles du serveur, dans la fenêtre SSH ouverte depuis PowerShell.

> **Comment ça marche**
>
> - **Une seule adresse web** (par exemple `https://chezamani.duckdns.org`) sert à la fois l'application et le serveur.
> - **Installation des appareils** : on « installe » l'application depuis Chrome sur les tablettes Android, le téléphone du gérant et l'ordinateur de caisse. Aucun Play Store.
> - **Sans internet**, chaque appareil continue de fonctionner : commandes, caisse, stock. Tout est envoyé au serveur dès le retour de la connexion.
> - **Comptes** : seul l'administrateur crée, modifie ou supprime un compte. Chaque employé a un code personnel de **6 à 10 chiffres**.

---

## 1. Choisir l'hébergement

Il faut un petit serveur toujours allumé, appelé **VPS** (serveur privé virtuel), sous **Ubuntu 24.04**. Un restaurant a besoin de peu : 2 cœurs, 2 à 4 Go de mémoire, 20 Go de disque suffisent largement.

Prix observés en novembre 2026, hors TVA. Ils changent souvent : vérifiez sur le site avant de commander.

| Offre | Prix indicatif | Pour | Contre |
|---|---|---|---|
| **Contabo Cloud VPS 10** (4 cœurs, 8 Go, 75 Go NVMe) — <https://contabo.com/fr/vps/> | ≈ 4,40 à 5,50 € / mois (≈ 2 900 à 3 600 F CFA) | Le plus de puissance pour le prix ; centres en Europe | Support plus lent ; le prix de renouvellement peut être plus élevé que le premier mois |
| **Hetzner Cloud CX23** (2 cœurs, 4 Go, 40 Go) — <https://www.hetzner.com/cloud> | ≈ 5,50 à 6 € / mois | Très fiable, rapide, facturé à l'heure | Prix en hausse en 2026 ; offre parfois indisponible à la commande |
| **Oracle Cloud « Always Free »** — <https://www.oracle.com/cloud/free/> | Gratuit | Gratuit (machine ARM, environ 2 cœurs et 12 Go) | Inscription avec carte bancaire ; limites réduites en 2026 ; machines inactives parfois récupérées : à réserver aux essais |

**Recommandation : Contabo Cloud VPS 10** pour le meilleur rapport prix/puissance, ou **Hetzner** si vous préférez la fiabilité. L'offre gratuite d'Oracle convient pour tester, pas pour encaisser un vrai service.

À la commande, choisissez **Ubuntu 24.04** et un centre de données en **Europe** (Allemagne ou France : le plus proche de l'Afrique de l'Ouest). Vous recevez par e-mail une **adresse IP** (par exemple `185.12.34.56`) et le **mot de passe root**.

---

## 2. Adresse web (gratuite) et HTTPS

L'installation d'une PWA et le mode hors ligne exigent **HTTPS**, donc un nom de domaine.

**Option gratuite : DuckDNS**

1. Allez sur <https://www.duckdns.org>, connectez-vous (avec Google, par exemple).
2. Créez le sous-domaine `chezamani` : votre adresse sera **`chezamani.duckdns.org`**. Si ce nom est pris, choisissez-en un autre.
3. Dans le champ **current ip**, mettez l'adresse IP du VPS, puis cliquez sur **update ip**.

**Option payante** : un domaine à vous (par exemple `chezamani.com`, environ 10 € par an chez OVH, Namecheap ou Gandi). Créez un enregistrement **A** qui pointe vers l'IP du VPS.

---

## 3. Préparer l'ordinateur Windows (une seule fois)

Ouvrez **PowerShell en administrateur** (clic droit sur Démarrer → Terminal (administrateur)) :

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
New-Item -ItemType Directory -Force C:\src | Out-Null
git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";C:\src\flutter\bin", "User")
```

**Fermez puis rouvrez PowerShell**, puis vérifiez :

```powershell
flutter --version
node --version
ssh -V
```

`ssh` et `scp` sont déjà inclus dans Windows 10 et 11.

---

## 4. Récupérer le code et construire l'application

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
- `--dart-define=SERVEUR=true` est **indispensable**. Sans cette option, l'application démarre en mode démonstration, avec des données fictives non enregistrées.
- `generer-sw.mjs` prépare la copie hors ligne de l'application. À relancer après chaque `flutter build web`.

**Préparer le paquet à envoyer :**

```powershell
cd C:\src\amani\gestion_restaurant
Remove-Item -Recurse -Force envoi -ErrorAction SilentlyContinue
New-Item -ItemType Directory envoi | Out-Null
Copy-Item -Recurse build\web envoi\web
robocopy serveur envoi\serveur /E /XD node_modules /XF .env | Out-Null
tar -czf amani.tgz -C envoi .
```

---

## 5. Installer le serveur (une seule fois)

Remplacez `185.12.34.56` par l'IP de votre VPS, puis envoyez le paquet et connectez-vous :

```powershell
scp C:\src\amani\gestion_restaurant\amani.tgz root@185.12.34.56:/root/
ssh root@185.12.34.56
```

À la première connexion, tapez `yes`, puis le mot de passe root reçu par e-mail.

**Dans la fenêtre SSH (sur le serveur)**, remplacez le domaine et l'e-mail par les vôtres :

```bash
passwd
mkdir -p /srv/amani && tar -xzf /root/amani.tgz -C /srv/amani
bash /srv/amani/serveur/deploiement/installer-serveur.sh chezamani.duckdns.org votre@email.com
bash /srv/amani/serveur/deploiement/demarrer.sh
```

- `passwd` change tout de suite le mot de passe root par un mot de passe long, à noter en lieu sûr.
- `installer-serveur.sh` dure environ 5 minutes. Il installe :
  - le pare-feu (seuls SSH, HTTP et HTTPS sont ouverts) ;
  - la protection contre les essais de mots de passe ;
  - les mises à jour de sécurité automatiques ;
  - Node.js 22, MySQL 8, Nginx et le certificat HTTPS gratuit ;
  - la sauvegarde quotidienne.

  Il génère aussi les mots de passe et le secret des sessions dans `/srv/amani/serveur/.env`.
- `demarrer.sh` doit se terminer par **Serveur en marche.**

Vérifiez dans un navigateur : `https://chezamani.duckdns.org` doit afficher l'écran **« Lier cet appareil »** avec le cadenas HTTPS.

---

## 6. Créer le restaurant et l'administrateur

Toujours dans la fenêtre SSH. Choisissez **votre code administrateur** (6 à 10 chiffres, pas `123456`, pas `111111`) : le code `482615` ci-dessous n'est qu'un exemple, ne le gardez pas.

```bash
cd /srv/amani/serveur
sudo -u amani npm run creer-restaurant -- --id chez-amani --nom "Restaurant Chez les Amani" --admin "Patron" --pin 482615 --telephone "+226 65 91 11 76"
```

Le script affiche un **code de liaison de 8 caractères**, valable **15 minutes**. Ce code sert à lier le téléphone du gérant.

---

## 7. Installer l'application sur les appareils

### Téléphone du gérant (le premier)

1. Ouvrez **Chrome** et allez sur `https://chezamani.duckdns.org`.
2. Menu ⋮ → **Installer l'application** (ou « Ajouter à l'écran d'accueil »). L'icône **Chez les Amani** apparaît comme une vraie application.
3. Ouvrez-la, tapez le **code de liaison** de l'étape 6, puis connectez-vous en **Patron** avec votre code.

Ce téléphone a les **droits administrateur permanents**. C'est lui qui liera tous les autres appareils.

### Ordinateur de caisse (Windows)

1. Ouvrez Chrome ou Edge sur `https://chezamani.duckdns.org`. Cliquez sur l'icône **Installer** à droite de la barre d'adresse.
2. Sur le téléphone du gérant : **Administration → Appareils → Lier un appareil**, type **Caisse**. Tapez ou scannez le code sur l'ordinateur.

**Ticket imprimé directement**, sans fenêtre de confirmation. Dans PowerShell, sur l'ordinateur de caisse :

```powershell
$URL = "https://chezamani.duckdns.org"
$CHROME = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$s = New-Object -ComObject WScript.Shell
foreach ($d in @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Startup"))) {
  $l = $s.CreateShortcut("$d\Caisse Chez les Amani.lnk"); $l.TargetPath = $CHROME
  $l.Arguments = "--kiosk-printing --app=$URL"; $l.IconLocation = "$CHROME,0"; $l.Save()
}
powercfg /change standby-timeout-ac 0
```

L'imprimante thermique 80 mm doit être **l'imprimante par défaut de Windows**. Fermez toutes les fenêtres Chrome avant d'utiliser ce raccourci.

### Tablettes des serveuses (Android)

Pour chaque tablette :

1. Ouvrez Chrome sur l'adresse, puis menu ⋮ → **Installer l'application**.
2. Sur le téléphone du gérant : **Lier un appareil** → type **Tablette**.
3. Sur la tablette, **scannez le QR code**.

Réglages conseillés sur chaque tablette :

- mise en veille de l'écran à 10 minutes ;
- optimisation de batterie désactivée pour Chrome ;
- Wi-Fi du restaurant mémorisé.

---

## 8. Créer les comptes de l'équipe

**Seul l'administrateur peut le faire, et seulement connecté avec internet** : le serveur vérifie son code.

**Administration → Comptes de l'équipe → Nouveau compte**, puis :

1. Indiquez le nom et le rôle (serveuse, caissier, gestionnaire de stock, administrateur).
2. Saisissez le **code personnel** de 6 à 10 chiffres, deux fois.

À savoir sur les codes :

- Les codes trop simples (suites, chiffres identiques, motifs répétés) sont refusés.
- Deux employés ne peuvent pas avoir le même code.
- Après **5 codes faux**, le compte est bloqué 15 minutes.

Pour gérer un compte existant :

- **Modifier** : changer le nom, le rôle ou le code, ou désactiver le compte.
- **Supprimer** : l'employé ne peut plus se connecter. Son nom reste dans l'historique (factures, journal).

Ensuite, saisissez les données du restaurant : **Tables et zones**, **Menu** (plats ivoiriens, grillades, boissons…), **Stock** de départ, **Paramètres** (adresse, texte du ticket).

---

## 9. Fonctionnement hors ligne

- **Coupure d'internet** : chaque appareil garde une copie des données et note les actions en attente. L'indicateur affiche « Hors ligne – N en attente ».
- **Retour du réseau** : tout part au serveur automatiquement, dans l'ordre. Les ventes de plusieurs tablettes s'additionnent sans conflit sur le stock.
- **Connexion hors ligne** : les employés peuvent se connecter, le code est vérifié sur l'appareil. En revanche, la **gestion des comptes**, du menu et les validations demandent un administrateur connecté en ligne, sauf sur le téléphone du gérant.
- **Appareil perdu ou volé** : **Administration → Appareils → Retirer**. Dès sa prochaine connexion, il efface ses données et revient à l'écran de liaison.

---

## 10. Sauvegardes

- **Automatique** : chaque nuit à 3 h, dans `/srv/amani/sauvegardes`, gardée 14 jours.
- **Copie sur l'ordinateur Windows**, à faire chaque semaine :

```powershell
New-Item -ItemType Directory -Force C:\amani-sauvegardes | Out-Null
scp "root@185.12.34.56:/srv/amani/sauvegardes/*.sql.gz" C:\amani-sauvegardes\
```

- **Restauration** (en cas de catastrophe uniquement), sur le serveur :

```bash
gunzip -c /srv/amani/sauvegardes/amani-AAAA-MM-JJ-0300.sql.gz | mysql amani
sudo -u amani pm2 reload amani
```

---

## 11. Mettre à jour la plateforme

1. Sur Windows : `git pull`, puis refaites toute l'**étape 4** (construction et paquet `amani.tgz`).
2. Envoyez le paquet et redémarrez, le matin, hors service :

```powershell
scp C:\src\amani\gestion_restaurant\amani.tgz root@185.12.34.56:/root/
ssh root@185.12.34.56 "tar -xzf /root/amani.tgz -C /srv/amani && bash /srv/amani/serveur/deploiement/demarrer.sh"
```

Le fichier `.env` et la base ne sont jamais écrasés. Les appareils chargent la nouvelle version au prochain démarrage de l'application.

---

## 12. Sécurité : ce qui est en place

| Protection | Détail |
|---|---|
| Connexions chiffrées | HTTPS obligatoire (Let's Encrypt), HSTS |
| Codes des employés | 6 à 10 chiffres, jamais stockés en clair (PBKDF2-SHA256 salé, 120 000 itérations), blocage après 5 erreurs |
| Comptes | Création, modification et suppression **uniquement** par l'administrateur, vérifiées par le serveur ; au moins un administrateur garanti |
| Appareils | Liaison par code à usage unique (15 min) ; jeton stocké sous forme d'empreinte ; retrait à distance |
| Droits | Chaque écriture est vérifiée par le serveur : une serveuse ne peut ni changer un prix, ni modifier une facture réglée, ni supprimer quoi que ce soit |
| Serveur | Pare-feu (22, 80, 443), fail2ban, mises à jour de sécurité automatiques, MySQL fermé à internet, application sans droits root, limitation du nombre de requêtes, en-têtes de sécurité (CSP) |
| Traçabilité | Journal d'audit : comptes créés, modifiés ou supprimés, appareils liés ou retirés, codes bloqués |

**À faire de votre côté :**

- un mot de passe root long ;
- un code administrateur que personne d'autre ne connaît ;
- une copie hebdomadaire des sauvegardes ;
- retirer tout appareil perdu sans attendre.

---

## 13. Dépannage

| Problème | Solution |
|---|---|
| `ssh` : « Connection refused » ou délai dépassé | Vérifiez l'IP ; attendez 2 minutes après la création du VPS |
| `certbot` échoue | Le domaine ne pointe pas encore vers l'IP du VPS (DuckDNS : « update ip »), ou le port 80 est bloqué |
| La page affiche « 502 Bad Gateway » | Sur le serveur : `sudo -u amani pm2 logs amani --lines 50`, puis `bash /srv/amani/serveur/deploiement/demarrer.sh` |
| L'application montre des données fictives | Construite sans `--dart-define=SERVEUR=true` : refaites l'étape 4 |
| Pas de bouton « Installer » dans Chrome | L'adresse doit être en **https://** ; rechargez la page une fois |
| « Code inconnu, expiré ou déjà utilisé » | Créez un nouveau code de liaison depuis le téléphone du gérant |
| Téléphone du gérant perdu | Sur le serveur : `cd /srv/amani/serveur && sudo -u amani npm run code-liaison -- --id chez-amani`, puis liez le nouveau téléphone et retirez l'ancien |
| « Gestion des comptes indisponible hors ligne » | Reconnectez-vous en tant qu'administrateur quand internet est revenu |

Sources des prix (novembre 2026) :

- Contabo : <https://pricingsaas.com/companies/contabo>
- Hetzner : <https://www.bitdoze.com/hetzner-cloud-cost-optimized-plans/> et <https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/>
- Oracle : <https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm>
