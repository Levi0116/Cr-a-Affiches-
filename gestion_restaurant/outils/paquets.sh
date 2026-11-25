#!/usr/bin/env bash
# Construit les deux paquets d'hébergement « front chez LWS, serveur chez alwaysdata » :
#   dist/amani-front-lws.zip            → à déposer dans le dossier du site LWS
#   dist/amani-serveur-alwaysdata.tar.gz → à déposer chez alwaysdata
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn --dart-define=SERVEUR=true
cp hebergement/lws/config.json hebergement/lws/.htaccess build/web/
node outils/generer-sw.mjs
rm -rf dist && mkdir -p dist/serveur
(cd build/web && zip -qr ../../dist/amani-front-lws.zip . -x '*.map' -x '.last_build_id')
tar -C serveur --exclude=node_modules --exclude=.env --exclude=test -cf - . | tar -C dist/serveur -xf -
(cd dist/serveur && npm ci --omit=dev --no-audit --no-fund --silent)
tar -C dist -czf dist/amani-serveur-alwaysdata.tar.gz --transform 's#^serveur#amani-serveur#' serveur
rm -rf dist/serveur
ls -la dist
