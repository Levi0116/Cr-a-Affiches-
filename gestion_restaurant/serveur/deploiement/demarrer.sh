#!/usr/bin/env bash
# Installe les dépendances, met la base à jour et (re)démarre le serveur.
# À relancer après chaque envoi d'une nouvelle version.
set -euo pipefail
# Les fichiers envoyés appartiennent à root : on les rend à l'utilisateur dédié.
chown -R amani:amani /srv/amani
chmod 600 /srv/amani/serveur/.env
cd /srv/amani/serveur
sudo -u amani npm ci --omit=dev --no-audit --no-fund
sudo -u amani npm run migrer
if sudo -u amani pm2 describe amani >/dev/null 2>&1; then
  sudo -u amani pm2 reload amani
else
  sudo -u amani pm2 start src/index.js --name amani --time --max-memory-restart 400M
  sudo -u amani pm2 save
  # Redémarrage automatique du serveur après un redémarrage de la machine.
  pm2 startup systemd -u amani --hp /home/amani
fi
sleep 2
curl -fsS http://127.0.0.1:3000/api/sante && echo && echo "Serveur en marche."
