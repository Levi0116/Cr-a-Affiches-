# Journal des versions

Format : `majeure.mineure.correctif` (section 9.1 du cahier des charges). La version de l'application est dans `pubspec.yaml` ; la dernière version publiée se déclare dans Firestore (`config/version`).

## 1.0.0 — première livraison

### Service
- Plan de salle temps réel par zone (libre / occupée / addition), prise de commande en 3 touches, tours horodatés, notes, articles indisponibles grisés, favoris, transfert, fusion, vente à emporter.
- Demande d'addition avec alerte sonore à la caisse ; demande d'annulation avec motif.

### Caisse
- Ticket provisoire automatique, pré-addition, facture numérotée sans trou (FAC-AAAA-NNNNNN), ticket thermique 80 mm.
- Pavé d'encaissement (billets cumulés, monnaie à rendre), partage par article ou en parts égales, ardoises, duplicata.
- Ouverture et clôture par comptage des billets et pièces, écart, journée verrouillée.

### Stock
- Déduction automatique à la vente, livraisons en casiers, coût moyen, pertes, inventaire validé, seuils, rupture automatique, fiches techniques des plats, consignes, historique.

### Administration
- Menu, tables et zones, employés, appareils (liaison par QR code, retrait à distance), paramètres, validations, avoirs, journal d'audit, tableau de bord, rapports jour / semaine / mois avec export Excel et PDF.

### Serveur
- Cloud Functions : liaison des appareils, élévation administrateur par PIN vérifié côté serveur, retrait, alertes de stock, notifications de validation, rapport du jour, sauvegarde quotidienne.
- Règles Firestore testées sur l'émulateur.

### Design
- Identité « Chez les Amani » (orange, vert forêt, crème), thèmes sombre (salle) et clair (caisse, administration), animations (rebond, compteurs, cascade, halo d'alerte, Hero carte de table → en-tête), chiffres à chasse fixe.

### Hors ligne
- Copie locale Firestore, file d'attente, indicateur « Hors ligne – N en attente », stock par incréments sans conflit.
