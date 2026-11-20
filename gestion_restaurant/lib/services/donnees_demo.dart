import '../core/pin.dart';
import 'db.dart';

/// Remplit le restaurant de démonstration « Chez les Amani » (menu type).
///
/// Codes de démonstration (6 chiffres) : Awa 241197, Fatou 315208,
/// Koffi (caisse) 426319, Moussa (stock) 537420, Patron (admin) 482615.
Future<void> remplirDemo(RestoDb db) async {
  final b = db.fs.batch();
  b.set(db.resto, {
    'nom': 'Restaurant Chez les Amani',
    // Adresse à compléter par l'administrateur dans les paramètres.
    'adresse': '',
    'telephone': '+226 65 91 11 76',
    'mentionsFacture': '',
    'slogan': 'Le goût de l’Afrique, la signature AMANI',
    'messageBasTicket': 'Merci et à bientôt chez les Amani !',
    'soumisTva': false,
    'tauxTva': 18,
    'deconnexionMinutes': 5,
  });

  const employes = [
    ('e-awa', 'Awa', 'serveuse', '241197'),
    ('e-fatou', 'Fatou', 'serveuse', '315208'),
    ('e-koffi', 'Koffi', 'caissier', '426319'),
    ('e-moussa', 'Moussa', 'gestionnaire', '537420'),
    ('e-patron', 'Patron', 'admin', '482615'),
  ];
  for (final (id, nom, role, pin) in employes) {
    b.set(db.employes.doc(id), {
      'nom': nom,
      'role': role,
      'actif': true,
      // Démonstration : moins d'itérations pour un démarrage instantané.
      'pinVerif': await hacherPin(pin, iterations: 2000),
    });
  }

  const zones = [('z-salle', 'Salle', 0), ('z-terrasse', 'Terrasse', 1), ('z-vip', 'VIP', 2)];
  for (final (id, nom, ordre) in zones) {
    b.set(db.zones.doc(id), {'nom': nom, 'ordre': ordre});
  }
  for (var i = 1; i <= 12; i++) {
    final zone = i <= 6 ? 'z-salle' : (i <= 10 ? 'z-terrasse' : 'z-vip');
    b.set(db.tables.doc('t-$i'), {'numero': '$i', 'idZone': zone, 'capacite': 4, 'statut': 'libre', 'active': true});
  }

  const categories = [
    ('c-plats', 'Plats ivoiriens', 0),
    ('c-grillades', 'Grillades & braisés', 1),
    ('c-accomp', 'Accompagnements', 2),
    ('c-bieres', 'Bières', 3),
    ('c-locales', 'Boissons locales', 4),
    ('c-sucreries', 'Sucreries', 5),
    ('c-eau', 'Eau', 6),
    ('c-cigarettes', 'Cigarettes', 7),
  ];
  for (final (id, nom, ordre) in categories) {
    b.set(db.categories.doc(id), {'nom': nom, 'ordre': ordre});
  }

  // (id, nom, catégorie, prix, type, stock, seuil, unités/casier, coût, suivi)
  const articles = [
    ('a-flag', 'Flag 65 cl', 'c-bieres', 700, 'revendu', 48, 12, 12, 520, true),
    ('a-castel', 'Castel 65 cl', 'c-bieres', 700, 'revendu', 36, 12, 12, 520, true),
    ('a-beaufort', 'Beaufort 33 cl', 'c-bieres', 600, 'revendu', 24, 12, 24, 430, true),
    ('a-guinness', 'Guinness 33 cl', 'c-bieres', 800, 'revendu', 3, 6, 24, 600, true),
    ('a-coca', 'Coca-Cola 33 cl', 'c-sucreries', 500, 'revendu', 30, 10, 24, 330, true),
    ('a-fanta', 'Fanta 33 cl', 'c-sucreries', 500, 'revendu', 0, 10, 24, 330, true),
    ('a-youzou', 'Youzou', 'c-sucreries', 500, 'revendu', 20, 6, 24, 300, true),
    ('a-eau', 'Eau minérale 1,5 L', 'c-eau', 500, 'revendu', 40, 10, 6, 300, true),
    ('a-poulet', 'Poulet braisé', 'c-plats', 4000, 'prepare', 10, 2, 0, 2200, true),
    ('a-poisson', 'Poisson braisé', 'c-plats', 4500, 'prepare', 8, 2, 0, 2500, true),
    ('a-garba', 'Garba (attiéké thon)', 'c-plats', 1000, 'prepare', 0, 0, 0, 500, false),
    ('a-attieke-poisson', 'Attiéké poisson braisé', 'c-plats', 3500, 'prepare', 0, 0, 0, 1900, false),
    ('a-kedjenou', 'Kedjenou de poulet', 'c-plats', 4500, 'prepare', 0, 0, 0, 2400, false),
    ('a-foutou', 'Foutou banane sauce graine', 'c-plats', 3500, 'prepare', 0, 0, 0, 1800, false),
    ('a-placali', 'Placali sauce kplala', 'c-plats', 3000, 'prepare', 0, 0, 0, 1500, false),
    ('a-riz-arachide', 'Riz sauce arachide', 'c-plats', 2500, 'prepare', 0, 0, 0, 1200, false),
    ('a-alloco-poisson', 'Alloco poisson', 'c-plats', 2500, 'prepare', 0, 0, 0, 1300, false),
    ('a-attieke', 'Portion d\'attiéké', 'c-accomp', 500, 'prepare', 0, 0, 0, 150, false),
    ('a-alloco', 'Portion d\'alloco', 'c-accomp', 500, 'prepare', 0, 0, 0, 200, false),
    ('a-riz', 'Riz blanc', 'c-accomp', 500, 'prepare', 0, 0, 0, 150, false),
    ('a-igname', 'Frites d\'igname', 'c-accomp', 700, 'prepare', 0, 0, 0, 250, false),
    ('a-bissap', 'Bissap maison', 'c-locales', 500, 'prepare', 0, 0, 0, 150, false),
    ('a-gingembre', 'Gnamakoudji (gingembre)', 'c-locales', 500, 'prepare', 0, 0, 0, 150, false),
    ('a-baobab', 'Jus de bouye (baobab)', 'c-locales', 600, 'prepare', 0, 0, 0, 200, false),
    ('a-bangui', 'Bangui (vin de palme)', 'c-locales', 1000, 'revendu', 12, 4, 0, 600, true),
    ('a-brochette', 'Brochette de bœuf', 'c-grillades', 1000, 'prepare', 30, 5, 0, 500, true),
    ('a-choukouya', 'Choukouya mouton', 'c-grillades', 3000, 'prepare', 6, 2, 0, 1700, true),
    ('a-cigarette', 'Cigarette (paquet)', 'c-cigarettes', 1500, 'revendu', 10, 3, 10, 1100, true),
  ];
  var ordre = 0;
  for (final (id, nom, cat, prix, type, stock, seuil, upc, cout, suivi) in articles) {
    b.set(db.articles.doc(id), {
      'nom': nom,
      'idCategorie': cat,
      'prixVente': prix,
      'type': type,
      'unite': type == 'revendu' ? 'bouteille' : 'portion',
      'stock': stock,
      'seuilAlerte': seuil,
      'disponible': true,
      'actif': true,
      'suiviStock': suivi,
      'coutMoyen': cout,
      'unitesParCasier': upc,
      'ordre': ordre++,
      'nbVentes': 0,
      // Bouteilles en verre consignées (bières, sucreries).
      'consigne': cat == 'c-bieres' || cat == 'c-sucreries',
      'vides': 0,
      'aRecette': false,
    });
  }

  // Ingrédients (matières premières) pour les fiches techniques.
  b.set(db.categories.doc('c-ingredients'), {'nom': 'Ingrédients', 'ordre': 99});
  // (id, nom, unité, stock, seuil, coût unitaire)
  const ingredients = [
    ('i-poulet', 'Poulet entier', 'pièce', 12, 3, 2000),
    ('i-poisson', 'Poisson (carpe)', 'pièce', 8, 2, 2200),
    ('i-oignon', 'Oignons', 'kg', 5, 1, 600),
    ('i-attieke', 'Attiéké', 'portion', 40, 10, 150),
    ('i-piment', 'Piment frais', 'kg', 1, 0.2, 1500),
  ];
  for (final (id, nom, unite, stock, seuil, cout) in ingredients) {
    b.set(db.articles.doc(id), {
      'nom': nom,
      'idCategorie': 'c-ingredients',
      'prixVente': 0,
      'type': 'ingredient',
      'unite': unite,
      'stock': stock,
      'seuilAlerte': seuil,
      'disponible': true,
      'actif': true,
      'suiviStock': true,
      'coutMoyen': cout,
      'unitesParCasier': 0,
      'ordre': ordre++,
      'nbVentes': 0,
      'consigne': false,
      'vides': 0,
      'aRecette': false,
    });
  }
  // Fiches techniques (section 3.3) : « Poulet braisé » = 1 poulet +
  // 0,1 kg d'oignons + 1 portion d'attiéké.
  const recettes = {
    'a-poulet': [
      ('i-poulet', 'Poulet entier', 1, 'pièce'),
      ('i-oignon', 'Oignons', 0.1, 'kg'),
      ('i-attieke', 'Attiéké', 1, 'portion'),
    ],
    'a-poisson': [
      ('i-poisson', 'Poisson (carpe)', 1, 'pièce'),
      ('i-oignon', 'Oignons', 0.1, 'kg'),
      ('i-piment', 'Piment frais', 0.02, 'kg'),
      ('i-attieke', 'Attiéké', 1, 'portion'),
    ],
  };
  for (final e in recettes.entries) {
    b.set(db.recettes.doc(e.key), {
      'idArticle': e.key,
      'ingredients': [
        for (final (id, nom, q, u) in e.value) {'idArticle': id, 'nom': nom, 'quantite': q, 'unite': u},
      ],
    });
    b.update(db.articles.doc(e.key), {'aRecette': true, 'suiviStock': false});
  }
  // Appareils déjà liés (en production : via Administration → Appareils).
  final lie = DateTime.now().subtract(const Duration(days: 12));
  const appareils = [
    ('ap-caisse', 'Ordinateur de caisse', 'caisse', false),
    ('ap-tab1', 'Tablette salle', 'tablette', false),
    ('ap-tab2', 'Tablette terrasse', 'tablette', false),
    ('ap-tel', 'Téléphone du patron', 'telephone', true),
  ];
  for (final (id, nom, type, admin) in appareils) {
    b.set(db.appareils.doc(id), {'nom': nom, 'type': type, 'admin': admin, 'actif': true, 'lieLe': lie});
  }
  b.set(db.fournisseurs.doc('f-solibra'), {'nom': 'Solibra', 'telephone': ''});
  b.set(db.fournisseurs.doc('f-brassivoire'), {'nom': 'Brassivoire', 'telephone': ''});
  await b.commit();
}
