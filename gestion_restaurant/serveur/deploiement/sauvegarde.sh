#!/usr/bin/env bash
# Sauvegarde compressée de la base MySQL (gardée 14 jours).
set -euo pipefail
DOSSIER=/srv/amani/sauvegardes
mkdir -p "$DOSSIER"
FICHIER="$DOSSIER/amani-$(date +%F-%H%M).sql.gz"
mysqldump --single-transaction --quick --routines amani | gzip -9 > "$FICHIER"
chmod 600 "$FICHIER"
find "$DOSSIER" -name 'amani-*.sql.gz' -mtime +14 -delete
echo "$(date -Is) sauvegarde OK : $FICHIER ($(du -h "$FICHIER" | cut -f1))"
