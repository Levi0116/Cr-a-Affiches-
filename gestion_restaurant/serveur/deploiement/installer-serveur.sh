#!/usr/bin/env bash
# Installation complète d'un VPS Ubuntu 24.04 pour la plateforme
# Restaurant Chez les Amani (à lancer UNE fois, en root) :
#
#   bash installer-serveur.sh chezamani.duckdns.org votre@email.com
#
# Installe : pare-feu, protection contre les attaques par mot de passe,
# mises à jour de sécurité automatiques, Node.js 22, MySQL 8, Nginx,
# certificat HTTPS gratuit (Let's Encrypt), PM2, sauvegardes quotidiennes.
set -euo pipefail

DOMAINE="${1:?Usage : bash installer-serveur.sh mon-domaine.fr mon@email.com}"
EMAIL="${2:?Indiquez un e-mail (alertes d’expiration du certificat HTTPS)}"
DOSSIER=/srv/amani
UTILISATEUR=amani

echo "== 1/8 Mises à jour du système"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get upgrade -yq
apt-get install -yq curl ca-certificates gnupg ufw fail2ban unattended-upgrades nginx mysql-server certbot python3-certbot-nginx

echo "== 2/8 Pare-feu : seuls SSH, HTTP et HTTPS sont ouverts"
# Certains VPS d'entrée de gamme (conteneurs LXC) n'autorisent pas ufw :
# on continue alors, et on utilise le pare-feu du panneau de l'hébergeur.
if ufw allow OpenSSH && ufw allow 'Nginx Full' && ufw --force enable; then
  echo "Pare-feu actif."
else
  echo "ATTENTION : pare-feu ufw indisponible sur ce VPS. Activez le pare-feu de l'espace client (ports 22, 80, 443)."
fi
systemctl enable --now fail2ban || echo "ATTENTION : fail2ban indisponible sur ce VPS."
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "== 3/8 Node.js 22 et PM2"
if ! command -v node >/dev/null || [[ "$(node -v)" != v22* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -yq nodejs
fi
npm install -g pm2@latest

echo "== 4/8 Utilisateur dédié (le serveur ne tourne jamais en root)"
id "$UTILISATEUR" >/dev/null 2>&1 || useradd --system --create-home --shell /bin/bash "$UTILISATEUR"
mkdir -p "$DOSSIER" "$DOSSIER/sauvegardes"
chown -R "$UTILISATEUR:$UTILISATEUR" "$DOSSIER"
chmod 750 "$DOSSIER"

echo "== 5/8 Base MySQL et utilisateur aux droits limités"
FICHIER_MDP=/root/.amani-mysql
if [[ ! -f $FICHIER_MDP ]]; then
  openssl rand -base64 30 | tr -d '/+=' | head -c 32 > "$FICHIER_MDP"
  chmod 600 "$FICHIER_MDP"
fi
MDP=$(cat "$FICHIER_MDP")
mysql <<SQL
CREATE DATABASE IF NOT EXISTS amani CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'amani'@'localhost' IDENTIFIED BY '${MDP}';
ALTER USER 'amani'@'localhost' IDENTIFIED BY '${MDP}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, REFERENCES, LOCK TABLES ON amani.* TO 'amani'@'localhost';
FLUSH PRIVILEGES;
SQL
# MySQL n'écoute que sur la machine elle-même (jamais depuis internet).
sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mysql.conf.d/mysqld.cnf || true
systemctl restart mysql

echo "== 6/8 Fichier de configuration .env (secrets générés)"
mkdir -p "$DOSSIER/serveur"
if [[ ! -f $DOSSIER/serveur/.env ]]; then
  cat > "$DOSSIER/serveur/.env" <<ENV
PORT=3000
MYSQL_HOTE=127.0.0.1
MYSQL_PORT=3306
MYSQL_BASE=amani
MYSQL_UTILISATEUR=amani
MYSQL_MOT_DE_PASSE=${MDP}
SECRET_SESSIONS=$(openssl rand -base64 64 | tr -d '\n/+=')
DUREE_SESSION_H=12
DOSSIER_PWA=../web
VERSION_DERNIERE=2.0.0
VERSION_MINIMALE=2.0.0
VERSION_NOTES=
ENV
fi
chown -R "$UTILISATEUR:$UTILISATEUR" "$DOSSIER"
chmod 600 "$DOSSIER/serveur/.env"

echo "== 7/8 Nginx (HTTPS) devant le serveur Node.js"
sed "s/__DOMAINE__/${DOMAINE}/g" "$(dirname "$0")/nginx-amani.conf" > /etc/nginx/sites-available/amani
ln -sf /etc/nginx/sites-available/amani /etc/nginx/sites-enabled/amani
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
certbot --nginx -d "$DOMAINE" --non-interactive --agree-tos -m "$EMAIL" --redirect

echo "== 8/8 Sauvegarde quotidienne de la base (3 h du matin, 14 jours gardés)"
install -m 750 "$(dirname "$0")/sauvegarde.sh" /usr/local/bin/amani-sauvegarde
cat > /etc/cron.d/amani-sauvegarde <<CRON
0 3 * * * root /usr/local/bin/amani-sauvegarde >> /var/log/amani-sauvegarde.log 2>&1
CRON

echo
echo "Serveur prêt. Étape suivante (depuis Windows) : envoyer l'application,"
echo "puis lancer : bash $DOSSIER/serveur/deploiement/demarrer.sh"
