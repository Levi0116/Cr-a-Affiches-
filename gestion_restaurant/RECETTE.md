# Recette et procès-verbal de livraison

À dérouler **par le client lui-même**, sur le vrai matériel (tablettes, ordinateur de caisse, imprimante thermique), avant la mise en service (phase 10.6 du cahier des charges). Cocher chaque ligne.

**Restaurant :** Restaurant Chez les Amani · **Version :** 2.0.0 · **Date :** ____ / ____ / ________

## A. Mise en service

- [ ] L'application est **installée** (Chrome → « Installer l'application ») sur chaque appareil et s'ouvre comme une application.
- [ ] Le téléphone du gérant est lié (code du script de création) et voit l'administration.
- [ ] L'ordinateur de caisse est lié depuis *Administration → Appareils* (QR code ou code à 8 caractères).
- [ ] Chaque tablette est liée ; une tablette **non liée** n'affiche que l'écran « Lier cet appareil ».
- [ ] Seul l'administrateur crée, modifie et supprime les comptes ; un code trop simple (123456, 111111) est refusé.
- [ ] Chaque employé se connecte avec son code de 6 chiffres ou plus ; après 5 codes faux, le compte est bloqué 15 minutes.
- [ ] Après quelques minutes sans toucher l'écran, l'employé est déconnecté.

## B. Service en salle (tablette)

- [ ] Le plan de salle montre les tables par zone : vert libre, ambre occupée, bleu addition (avec le libellé écrit).
- [ ] Ouvrir une table, choisir les couverts, ajouter des articles en 3 touches maximum ; les quantités se corrigent avec + et −.
- [ ] Une note (« bien glacée ») apparaît sur le ticket de la caisse.
- [ ] Un article épuisé est grisé « Indisponible » ; un stock faible affiche « reste 3 ».
- [ ] Valider : la commande apparaît à la caisse en quelques secondes ; le stock baisse.
- [ ] Deuxième tour sur la même table : horodaté, ajouté au même ticket.
- [ ] Transférer une table, fusionner deux tables, vente à emporter.
- [ ] Demander l'addition : la table passe en bleu et la caisse sonne.

## C. Caisse

- [ ] Ouvrir la caisse en comptant le fond par billets et pièces.
- [ ] Pré-addition imprimée « à titre indicatif », sans numéro.
- [ ] Facture finale numérotée FAC-AAAA-NNNNNN, sans trou dans la suite.
- [ ] Encaissement sur le pavé : billets cumulés, monnaie à rendre exacte ; ticket 80 mm imprimé directement.
- [ ] Partage en parts égales et par article : une facture par part, somme exacte.
- [ ] Mise en ardoise d'un client, puis remboursement partiel.
- [ ] Réimpression marquée « DUPLICATA ».
- [ ] Clôture : comptage, écart affiché (juste / manquant / excédent), rapport imprimé, journée verrouillée.

## D. Validations et contrôle (gérant)

- [ ] Une serveuse demande une annulation : la demande apparaît aussitôt dans la cloche du téléphone du gérant.
- [ ] Le gérant valide depuis son téléphone : la ligne est barrée « annulée », le stock et le total se corrigent seuls.
- [ ] Sur l'ordinateur de caisse, l'administrateur connecté voit « Droits administrateur » et peut valider.
- [ ] Une remise et un article offert ne s'appliquent qu'après validation.
- [ ] Le journal d'audit montre toutes ces actions, avec auteur, appareil et heure.
- [ ] Un avoir AV-AAAA-NNNNNN corrige une facture payée (qui, elle, ne change pas).

## E. Stock

- [ ] Livraison en casiers convertie en bouteilles ; coût moyen mis à jour.
- [ ] Plat à fiche technique : la vente retire les ingrédients ; les portions possibles baissent.
- [ ] Passage sous le seuil : alerte dans la cloche (tous les appareils), y compris celui du gérant.
- [ ] Perte avec motif ; inventaire compté soumis à validation.
- [ ] Consignes : vides comptés à la vente, rendus à la livraison.

## F. Hors ligne (phase 10.3)

- [ ] Fermer puis rouvrir l'application en mode avion : elle démarre quand même et l'employé peut se connecter.
- [ ] Mettre une tablette en mode avion pendant une commande : la commande est gardée (« Hors ligne – N en attente »), puis envoyée au retour du réseau.
- [ ] Couper le Wi-Fi 30 minutes pendant le service : tout continue sur les tablettes ; tout arrive à la caisse au retour.
- [ ] Vendre deux fois la dernière bouteille hors ligne : le stock devient négatif et une alerte est envoyée, sans bloquer le service.

## G. Rapports

- [ ] Rapport du jour / de la semaine / du mois conforme aux factures, comparé à la période précédente.
- [ ] Export Excel et PDF ouverts sur l'ordinateur du gérant.

## H. Matériel et charge (phases 10.4 et 10.5)

- [ ] Soirée simulée : 3 tablettes, environ 100 commandes, sans ralentissement ni erreur de calcul.
- [ ] L'imprimante thermique imprime tickets, pré-additions et clôture lisiblement.

---

## Procès-verbal

Le client déclare avoir déroulé les scénarios ci-dessus.

- [ ] Recette **acceptée sans réserve**
- [ ] Recette **acceptée avec réserves** (à lever avant le : ____ / ____ / ________) :

  ______________________________________________________________________

  ______________________________________________________________________

| | Le client | Le prestataire |
|---|---|---|
| Nom | | |
| Date | | |
| Signature | | |
