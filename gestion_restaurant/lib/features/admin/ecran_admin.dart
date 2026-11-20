import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/stock_calc.dart';
import '../../core/pin.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../theme/motif.dart';
import '../../widgets/banniere_version.dart';
import '../../widgets/barre_etat.dart';
import '../../widgets/cloche_alertes.dart';
import '../../widgets/commun.dart';
import '../../widgets/panneaux.dart';
import '../caisse/ecran_caisse.dart';
import '../salle/ecran_salle.dart';
import '../stock/ecran_stock.dart';
import 'appareils.dart';
import 'rapports.dart';

/// ============================================================================
///  ADMINISTRATION (section 3.4) — ambiance claire « crème Amani »
/// ============================================================================
///
/// Barre latérale groupée (Pilotage, Service, Configuration, Contrôle) avec
/// compteurs, en-tête avec droits administrateur, alertes et réseau, et
/// transition douce entre les pages.
class EcranAdmin extends ConsumerStatefulWidget {
  const EcranAdmin({super.key});
  @override
  ConsumerState<EcranAdmin> createState() => _EcranAdminState();
}

enum _Page {
  tableau,
  validations,
  rapports,
  caisse,
  salle,
  stock,
  menu,
  tables,
  employes,
  appareils,
  parametres,
  audit,
}

class _Entree {
  final _Page page;
  final String groupe;
  final IconData icone;
  final String titre;
  final int compte;
  final bool alerte;
  const _Entree(this.page, this.groupe, this.icone, this.titre, {this.compte = 0, this.alerte = false});
}

class _EcranAdminState extends ConsumerState<EcranAdmin> {
  _Page _page = _Page.tableau;

  Widget _corps(_Page p) => switch (p) {
    _Page.tableau => _TableauDeBord(onAller: _aller),
    _Page.validations => const _Validations(),
    _Page.rapports => const EcranRapports(),
    _Page.caisse => const EcranCaisse(avecBarre: false),
    _Page.salle => const EcranSalle(avecBarre: false),
    _Page.stock => const EcranStock(avecBarre: false),
    _Page.menu => const _Menu(),
    _Page.tables => const _Tables(),
    _Page.employes => const _Employes(),
    _Page.appareils => const PageAppareils(),
    _Page.parametres => const _Parametres(),
    _Page.audit => const _Audit(),
  };

  void _aller(_Page p) => setState(() => _page = p);

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final attente = ref.watch(demandesEnAttenteProvider).value?.length ?? 0;
    final sessions = ref.watch(sessionsEnCoursProvider).value ?? const <SessionTable>[];
    final aEncaisser = sessions.where((s) => s.statut != StatutSession.ouverte).length;
    final sousSeuil = (ref.watch(articlesProvider).value ?? const <Article>[])
        .where((a) => a.actif && a.sousSeuil)
        .length;
    final entrees = [
      const _Entree(_Page.tableau, 'Pilotage', Icons.space_dashboard_rounded, 'Tableau de bord'),
      _Entree(
        _Page.validations,
        'Pilotage',
        Icons.verified_rounded,
        'Validations',
        compte: attente,
        alerte: attente > 0,
      ),
      const _Entree(_Page.rapports, 'Pilotage', Icons.insights_rounded, 'Rapports'),
      _Entree(
        _Page.caisse,
        'Service',
        Icons.point_of_sale_rounded,
        'Caisse',
        compte: aEncaisser,
        alerte: aEncaisser > 0,
      ),
      _Entree(_Page.salle, 'Service', Icons.table_restaurant_rounded, 'Salle', compte: sessions.length),
      _Entree(_Page.stock, 'Service', Icons.inventory_2_rounded, 'Stock', compte: sousSeuil),
      const _Entree(_Page.menu, 'Configuration', Icons.restaurant_menu_rounded, 'Menu'),
      const _Entree(_Page.tables, 'Configuration', Icons.grid_view_rounded, 'Tables et zones'),
      const _Entree(_Page.employes, 'Configuration', Icons.people_alt_rounded, 'Employés'),
      const _Entree(_Page.appareils, 'Configuration', Icons.devices_rounded, 'Appareils'),
      const _Entree(_Page.parametres, 'Configuration', Icons.tune_rounded, 'Paramètres'),
      const _Entree(_Page.audit, 'Contrôle', Icons.history_rounded, 'Journal d’audit'),
    ];
    final courante = entrees.firstWhere((e) => e.page == _page);
    final largeur = MediaQuery.sizeOf(context).width;
    final mode = largeur >= 1180 ? _ModeNav.large : (largeur >= 820 ? _ModeNav.icones : _ModeNav.tiroir);

    final nav = _BarreLaterale(
      entrees: entrees,
      page: _page,
      mode: mode == _ModeNav.tiroir ? _ModeNav.large : mode,
      onPage: (pg) {
        _aller(pg);
        if (mode == _ModeNav.tiroir) Navigator.of(context).maybePop();
      },
    );
    final corps = Column(
      children: [
        _BarreHaut(titre: courante.titre, icone: courante.icone, menu: mode == _ModeNav.tiroir),
        Expanded(
          child: AnimatedSwitcher(
            duration: duree(context, 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_page), child: _corps(_page)),
          ),
        ),
      ],
    );
    return Theme(
      data: AppTheme.clair,
      child: Scaffold(
        backgroundColor: p.fond,
        drawer: mode == _ModeNav.tiroir ? Drawer(width: 288, child: nav) : null,
        body: SafeArea(
          child: mode == _ModeNav.tiroir
              ? corps
              : Row(
                  children: [
                    nav,
                    Expanded(child: corps),
                  ],
                ),
        ),
      ),
    );
  }
}

enum _ModeNav { large, icones, tiroir }

class _BarreLaterale extends ConsumerWidget {
  final List<_Entree> entrees;
  final _Page page;
  final _ModeNav mode;
  final ValueChanged<_Page> onPage;
  const _BarreLaterale({required this.entrees, required this.page, required this.mode, required this.onPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final large = mode == _ModeNav.large;
    final resto = ref.watch(restaurantProvider).value;
    final e = ref.watch(utilisateurProvider);
    final groupes = <String>[];
    for (final x in entrees) {
      if (!groupes.contains(x.groupe)) groupes.add(x.groupe);
    }
    return Container(
      width: large ? 272 : 92,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.bordure)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(large ? 18 : 14, 18, large ? 18 : 14, 10),
            child: Row(
              children: [
                Hero(
                  tag: 'logo',
                  child: LogoResto(nom: resto?.nom ?? '', taille: large ? 52 : 60),
                ),
                if (large) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Administration', style: AppTypo.titre(p.texte, taille: 18)),
                        Text(
                          resto?.nom ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypo.etiquette(p.texteSecondaire, taille: 12, poids: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10, vertical: 6),
              children: [
                for (final g in groupes) ...[
                  if (large)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                      child: Text(
                        g.toUpperCase(),
                        style: AppTypo.etiquette(
                          p.texteDiscret,
                          taille: 11,
                          poids: FontWeight.w700,
                        ).copyWith(letterSpacing: 1.2),
                      ),
                    )
                  else
                    Divider(height: 18, color: p.bordure),
                  for (final x in entrees.where((x) => x.groupe == g))
                    _ItemNav(entree: x, actif: x.page == page, large: large, onTap: () => onPage(x.page)),
                ],
              ],
            ),
          ),
          if (e != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Semantics(
                container: true,
                button: true,
                label: '${e.nom}, changer d’utilisateur',
                excludeSemantics: true,
                child: BouncyTapWrapper(
                  onTap: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    ref.read(utilisateurProvider.notifier).deconnecter();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.fond,
                      borderRadius: BorderRadius.circular(identite.arrondi * 0.8),
                      border: Border.all(color: p.bordure),
                    ),
                    child: Row(
                      mainAxisAlignment: large ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: identite.secondaire,
                          child: Text(e.nom.characters.first, style: AppTypo.titre(Colors.white, taille: 15)),
                        ),
                        if (large) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.nom, style: AppTypo.etiquette(p.texte, taille: 14, poids: FontWeight.w700)),
                                Text('Changer d’utilisateur', style: AppTypo.etiquette(p.texteSecondaire, taille: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.logout_rounded, size: 18, color: p.texteDiscret),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemNav extends StatelessWidget {
  final _Entree entree;
  final bool actif;
  final bool large;
  final VoidCallback onTap;
  const _ItemNav({required this.entree, required this.actif, required this.large, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final x = entree;
    final c = actif ? Colors.white : p.texteSecondaire;
    final contenu = AnimatedContainer(
      duration: duree(context, 260),
      curve: Curves.easeOutCubic,
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 0),
      decoration: BoxDecoration(
        gradient: actif ? degradePrincipal(identite.secondaire) : null,
        borderRadius: BorderRadius.circular(identite.arrondi * 0.7),
        boxShadow: actif ? AppOmbres.lueur(identite.secondaire, force: 0.5) : null,
      ),
      child: Row(
        mainAxisAlignment: large ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(x.icone, color: c, size: 22),
              // Mode icônes : petite pastille qui ne masque pas l'icône.
              if (!large && x.compte > 0)
                Positioned(
                  right: -9,
                  top: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: x.alerte ? p.occupee : p.principale,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: actif ? Colors.white : p.surface, width: 1.5),
                    ),
                    child: Text(
                      '${x.compte}',
                      style: AppTypo.chiffres(
                        const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (large) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(x.titre, style: AppTypo.etiquette(c, taille: 15, poids: FontWeight.w600)),
            ),
            if (x.compte > 0)
              AnimatedContainer(
                duration: duree(context, 260),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: actif
                      ? Colors.white.withValues(alpha: 0.22)
                      : (x.alerte ? p.occupee.withValues(alpha: 0.15) : p.texte.withValues(alpha: 0.07)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SmoothCounterText.nombre(
                  x.compte,
                  style: AppTypo.etiquette(
                    actif ? Colors.white : (x.alerte ? p.occupee : p.texteSecondaire),
                    taille: 12,
                    poids: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: actif,
      label: '${x.titre}${x.compte > 0 ? ', ${x.compte}' : ''}',
      excludeSemantics: true,
      child: Tooltip(
        message: large ? '' : x.titre,
        child: BouncyTapWrapper(scale: 0.97, onTap: onTap, child: contenu),
      ),
    );
  }
}

class _BarreHaut extends StatelessWidget {
  final String titre;
  final IconData icone;
  final bool menu;
  const _BarreHaut({required this.titre, required this.icone, required this.menu});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final etroit = MediaQuery.sizeOf(context).width < 640;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.bordure)),
      ),
      child: Row(
        children: [
          if (menu)
            IconButton(
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Icon(Icons.menu_rounded, color: p.texte),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: duree(context, 240),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey(titre),
                children: [
                  Icon(icone, color: p.principale),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(titre, overflow: TextOverflow.ellipsis, style: AppTypo.titre(p.texte, taille: 22)),
                  ),
                ],
              ),
            ),
          ),
          if (!etroit) ...[const PastilleDroitsAdmin(), const SizedBox(width: 10)],
          const ClocheAlertes(),
          const SizedBox(width: 10),
          IndicateurConnexion(compact: etroit),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- Tableau de bord

class _TableauDeBord extends ConsumerWidget {
  final ValueChanged<_Page> onAller;
  const _TableauDeBord({required this.onAller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final hier = debutJour().subtract(const Duration(days: 1));
    final factures = ref.watch(facturesDepuisProvider(hier)).value ?? const <Facture>[];
    final sessions = ref.watch(sessionsEnCoursProvider).value ?? const <SessionTable>[];
    final articles = ref.watch(articlesProvider).value ?? const <Article>[];
    final ardoises = ref.watch(ardoisesProvider).value ?? const <Ardoise>[];
    final demandes = ref.watch(demandesEnAttenteProvider).value ?? const <DemandeValidation>[];
    final e = ref.watch(utilisateurProvider);
    final aujourdhui = debutJour();
    final vendues = factures.where((f) => f.statut != StatutFacture.emise && !f.date.isBefore(aujourdhui)).toList();
    final veille = factures.where((f) => f.statut != StatutFacture.emise && f.date.isBefore(aujourdhui)).toList();
    final ca = vendues.fold(0, (s, f) => s + f.total);
    final caHier = veille.fold(0, (s, f) => s + f.total);
    final enCours = sessions.fold(0, (s, x) => s + x.total);
    final ventes = <String, (int, int)>{};
    final parServeuse = <String, int>{};
    for (final f in vendues) {
      parServeuse[f.nomServeuse] = (parServeuse[f.nomServeuse] ?? 0) + f.total;
      if (f.partie != null && !f.partie!.startsWith('1/')) continue;
      for (final l in f.lignes.where((l) => !l.annulee)) {
        final (q, m) = ventes[l.nom] ?? (0, 0);
        ventes[l.nom] = (q + l.quantite, m + l.montant);
      }
    }
    final top = ventes.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final sousSeuil = articles.where((a) => a.actif && a.sousSeuil).toList();
    final h = DateTime.now().hour;
    final salut = h < 12 ? 'Bonjour' : (h < 18 ? 'Bon après-midi' : 'Bonsoir');
    final evo = caHier == 0 ? null : (ca - caHier) / caHier * 100;
    final large = MediaQuery.sizeOf(context).width >= 1180;

    final heros = ClipRRect(
      borderRadius: BorderRadius.circular(identite.arrondi * 1.2),
      child: Container(
        decoration: BoxDecoration(gradient: degradePrincipal(identite.secondaire)),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              width: 260,
              height: 260,
              child: CustomPaint(painter: MotifPainter(couleur: identite.accent, opacite: 0.14)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Wrap(
                spacing: 32,
                runSpacing: 18,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$salut ${e?.nom ?? ''} 👋', style: AppTypo.titre(Colors.white, taille: 26)),
                      Text(
                        dateJourFr(DateTime.now()),
                        style: AppTypo.etiquette(
                          Colors.white.withValues(alpha: 0.75),
                          taille: 14,
                          poids: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Chiffre d’affaires du jour', style: AppTypo.etiquette(identite.accent, taille: 14)),
                      SmoothCounterText(ca, millisecondes: 900, style: AppTypo.montant(Colors.white, taille: 44)),
                      Row(
                        children: [
                          if (evo != null) ...[
                            Icon(
                              evo >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 16,
                              color: identite.accent,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            evo == null
                                ? '${vendues.length} facture${vendues.length > 1 ? 's' : ''}'
                                : '${evo >= 0 ? '+' : ''}${evo.toStringAsFixed(0)} % vs hier · ${vendues.length} facture${vendues.length > 1 ? 's' : ''}',
                            style: AppTypo.chiffres(
                              AppTypo.etiquette(Colors.white.withValues(alpha: 0.85), taille: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _BoutonRaccourci(
                        icone: Icons.insights_rounded,
                        texte: 'Rapports',
                        onTap: () => onAller(_Page.rapports),
                      ),
                      _BoutonRaccourci(
                        icone: Icons.restaurant_menu_rounded,
                        texte: 'Menu',
                        onTap: () => onAller(_Page.menu),
                      ),
                      _BoutonRaccourci(
                        icone: Icons.devices_rounded,
                        texte: 'Appareils',
                        onTap: () => onAller(_Page.appareils),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    var n = 0;
    final tuiles = Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _Tuile(
          index: n++,
          titre: 'En cours · ${sessions.length} table${sessions.length > 1 ? 's' : ''}',
          icone: Icons.table_restaurant_rounded,
          couleur: p.occupee,
          valeur: SmoothCounterText(enCours, style: AppTypo.montant(p.texte, taille: 22)),
          onTap: () => onAller(_Page.salle),
        ),
        _Tuile(
          index: n++,
          titre: 'Validations en attente',
          icone: Icons.verified_rounded,
          couleur: demandes.isEmpty ? p.libre : p.addition,
          alerte: demandes.isNotEmpty,
          valeur: SmoothCounterText.nombre(demandes.length, style: AppTypo.montant(p.texte, taille: 22)),
          onTap: () => onAller(_Page.validations),
        ),
        _Tuile(
          index: n++,
          titre: 'Articles sous le seuil',
          icone: Icons.warning_amber_rounded,
          couleur: sousSeuil.isEmpty ? p.libre : p.erreur,
          alerte: sousSeuil.isNotEmpty,
          valeur: SmoothCounterText.nombre(sousSeuil.length, style: AppTypo.montant(p.texte, taille: 22)),
          onTap: () => onAller(_Page.stock),
        ),
        _Tuile(
          index: n++,
          titre: 'Ardoises en cours',
          icone: Icons.menu_book_rounded,
          couleur: p.addition,
          valeur: SmoothCounterText(
            ardoises.fold(0, (s, a) => s + a.montantDu),
            style: AppTypo.montant(p.texte, taille: 22),
          ),
          onTap: () => onAller(_Page.caisse),
        ),
      ],
    );

    final maxVente = top.isEmpty ? 1 : top.first.value.$2;
    final meilleures = PanneauCaisse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TitreSection(icone: Icons.local_fire_department_rounded, titre: 'Meilleures ventes du jour'),
          const SizedBox(height: 12),
          if (top.isEmpty)
            Text('Pas encore de vente aujourd’hui.', style: AppTypo.etiquette(p.texteSecondaire, taille: 14)),
          for (final (i, v) in top.take(6).indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: StaggeredEntrance(
                index: i,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(v.key, style: AppTypo.etiquette(p.texte, taille: 14))),
                        Text(
                          '${v.value.$1} × · ',
                          style: AppTypo.chiffres(AppTypo.etiquette(p.texteDiscret, taille: 13)),
                        ),
                        Text(fcfa(v.value.$2), style: AppTypo.montant(p.texte, taille: 14)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: v.value.$2 / maxVente),
                      duration: duree(context, 650 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: t,
                          minHeight: 8,
                          color: p.principale,
                          backgroundColor: p.texte.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    final serveuses = PanneauCaisse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TitreSection(icone: Icons.room_service_rounded, titre: 'Ventes par serveuse'),
          const SizedBox(height: 12),
          if (parServeuse.isEmpty) Text('—', style: AppTypo.etiquette(p.texteSecondaire, taille: 14)),
          for (final s in (parServeuse.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: p.principale.withValues(alpha: 0.12),
                    child: Text(s.key.characters.first, style: AppTypo.titre(p.principale, taille: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.key, style: AppTypo.etiquette(p.texte, taille: 14))),
                  Text(fcfa(s.value), style: AppTypo.montant(p.texte, taille: 14)),
                ],
              ),
            ),
          if (sousSeuil.isNotEmpty) ...[
            const SizedBox(height: 14),
            const TitreSection(icone: Icons.inventory_2_rounded, titre: 'À réapprovisionner'),
            const SizedBox(height: 8),
            for (final a in sousSeuil.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 9, color: a.stock <= 0 ? p.erreur : p.occupee),
                    const SizedBox(width: 10),
                    Expanded(child: Text(a.nom, style: AppTypo.etiquette(p.texte, taille: 14))),
                    Text(
                      qte(a.stock, a.unite),
                      style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 13)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        StaggeredEntrance(index: 0, child: heros),
        const SizedBox(height: 18),
        tuiles,
        const SizedBox(height: 18),
        if (large)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: meilleures),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: serveuses),
            ],
          )
        else ...[
          meilleures,
          const SizedBox(height: 18),
          serveuses,
        ],
      ],
    );
  }
}

class _BoutonRaccourci extends StatelessWidget {
  final IconData icone;
  final String texte;
  final VoidCallback onTap;
  const _BoutonRaccourci({required this.icone, required this.texte, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: texte,
    excludeSemantics: true,
    child: BouncyTapWrapper(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(identite.arrondi * 0.7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(texte, style: AppTypo.etiquette(Colors.white, taille: 14, poids: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}

class _Tuile extends StatelessWidget {
  final int index;
  final String titre;
  final IconData icone;
  final Color couleur;
  final Widget valeur;
  final bool alerte;
  final VoidCallback onTap;
  const _Tuile({
    required this.index,
    required this.titre,
    required this.icone,
    required this.couleur,
    required this.valeur,
    required this.onTap,
    this.alerte = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rayon = BorderRadius.circular(identite.arrondi);
    return StaggeredEntrance(
      index: index + 1,
      child: Semantics(
        container: true,
        button: true,
        label: titre,
        child: PulseGlow(
          active: alerte,
          couleur: couleur,
          rayon: rayon,
          child: BouncyTapWrapper(
            scale: 0.97,
            onTap: onTap,
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: rayon,
                border: Border.all(color: alerte ? couleur.withValues(alpha: 0.5) : p.bordure),
                boxShadow: AppOmbres.douce(p, force: 0.6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icone, color: couleur),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titre, style: AppTypo.etiquette(p.texteSecondaire, taille: 13)),
                        valeur,
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.texteDiscret),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Validations

class _Validations extends ConsumerWidget {
  const _Validations();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final async = ref.watch(demandesEnAttenteProvider);
    final droits = ref.watch(droitsAdminProvider);
    final maintenant = ref.watch(horlogeProvider).value ?? DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const EnTetePage(
          titre: 'Validations',
          description: 'Annulations, remises, articles offerts et ajustements d’inventaire demandés par l’équipe.',
        ),
        if (!droits)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: PanneauCaisse(
              couleur: p.occupee.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: p.occupee),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Connecté hors ligne : pour valider, reconnectez-vous quand internet est revenu (le serveur doit vérifier votre code).',
                      style: AppTypo.etiquette(p.texte, taille: 14, poids: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        async.when(
          loading: () => const Chargement(),
          error: (e, _) => Chargement(erreur: e),
          data: (liste) {
            if (liste.isEmpty) {
              return PanneauCaisse(
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: p.libre, size: 30),
                    const SizedBox(width: 12),
                    Text('Aucune demande en attente', style: AppTypo.etiquette(p.texte, taille: 16)),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final (i, d) in liste.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StaggeredEntrance(
                      key: ValueKey(d.id),
                      index: i,
                      child: _CarteDemande(demande: d, maintenant: maintenant),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CarteDemande extends ConsumerWidget {
  final DemandeValidation demande;
  final DateTime maintenant;
  const _CarteDemande({required this.demande, required this.maintenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final d = demande;
    final x = d.detail;
    final (String type, IconData icone, Color c, String titre) = switch (d.type) {
      TypeValidation.annulation => (
        'Annulation',
        Icons.remove_circle_rounded,
        p.erreur,
        '${x['quantite']} × ${x['nom']} · table ${x['numeroTable']} · ${fcfa(x['montant'] as num)}',
      ),
      TypeValidation.offert => (
        'Offert',
        Icons.redeem_rounded,
        p.principale,
        '${x['quantite']} × ${x['nom']} · table ${x['numeroTable']}',
      ),
      TypeValidation.remise => (
        'Remise',
        Icons.percent_rounded,
        p.addition,
        '${x['valeur']}${x['typeRemise'] == 'pourcentage' ? ' %' : ' F'} · table ${x['numeroTable']}',
      ),
      TypeValidation.ajustement => (
        'Inventaire',
        Icons.inventory_rounded,
        p.occupee,
        '${x['nom']} · théorique ${qte(x['theorique'] as num)}, compté ${qte(x['compte'] as num)} (écart ${qte(x['ecart'] as num)})',
      ),
    };
    final minutes = maintenant.difference(d.date).inMinutes;
    return PulseGlow(
      active: true,
      couleur: c,
      rayon: BorderRadius.circular(identite.arrondi * 1.1),
      periodeMs: 2400,
      child: PanneauCaisse(
        child: Wrap(
          spacing: 16,
          runSpacing: 14,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icone, color: c),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Pastille(type, c),
                            const SizedBox(width: 8),
                            Text(
                              '${d.demandeur} · ${minutes < 1 ? 'à l’instant' : 'il y a $minutes min'}',
                              style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          titre,
                          style: AppTypo.chiffres(AppTypo.etiquette(p.texte, taille: 16, poids: FontWeight.w700)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '« ${d.motif} »',
                          style: AppTypo.etiquette(p.texteSecondaire, taille: 14, poids: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Refuser'),
                  onPressed: () => essayer(
                    context,
                    () => ref.read(adminServiceProvider).traiterDemande(ref.read(acteurProvider)!, d, false),
                    succes: 'Demande refusée',
                  ),
                ),
                const SizedBox(width: 10),
                GradientActionButton(
                  label: 'Valider',
                  icone: Icons.check_rounded,
                  couleur: p.libre,
                  onPressed: () => essayer(context, () async {
                    await ref.read(adminServiceProvider).traiterDemande(ref.read(acteurProvider)!, d, true);
                    if (context.mounted) showSuccessBurst(context, 'Validé');
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------- Menu

class _Menu extends ConsumerWidget {
  const _Menu();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final articles = ref.watch(articlesProvider).value ?? const [];
    final acteur = ref.watch(acteurProvider)!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const EnTetePage(
          titre: 'Menu',
          description: 'Catégories, articles, prix, fiches techniques des plats et consignes.',
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Article'),
              onPressed: categories.isEmpty ? null : () => _editerArticle(context, ref, categories, null),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Catégorie'),
              onPressed: () async {
                final nom = await demanderTexte(context, 'Nouvelle catégorie', label: 'Nom');
                if (nom == null || !context.mounted) return;
                await essayer(
                  context,
                  () => ref.read(adminServiceProvider).enregistrerCategorie(acteur, nom: nom, ordre: categories.length),
                );
              },
            ),
          ],
        ),
        for (final c in categories) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Row(
              children: [
                Text(c.nom, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final nom = await demanderTexte(context, 'Renommer la catégorie', initial: c.nom);
                    if (nom == null || !context.mounted) return;
                    await essayer(
                      context,
                      () => ref
                          .read(adminServiceProvider)
                          .enregistrerCategorie(acteur, id: c.id, nom: nom, ordre: c.ordre),
                    );
                  },
                ),
              ],
            ),
          ),
          for (final a in articles.where((a) => a.idCategorie == c.id))
            ListTile(
              title: Text(a.nom, style: TextStyle(color: a.actif ? null : Colors.grey)),
              subtitle: Text(
                '${switch (a.type) {
                  TypeArticle.revendu => a.consigne ? 'Revendu · consigné' : 'Revendu',
                  TypeArticle.prepare => a.aRecette ? 'Plat · fiche technique' : 'Plat · portions du jour',
                  TypeArticle.ingredient => 'Ingrédient · ${qte(a.stock, a.unite)} en stock',
                }}'
                '${a.actif ? '' : ' · retiré du menu'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (a.type == TypeArticle.prepare)
                    TextButton.icon(
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('Fiche technique'),
                      onPressed: () => _editerRecette(context, ref, a, articles),
                    ),
                  if (a.type != TypeArticle.ingredient)
                    Text(fcfa(a.prixVente), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              onTap: () => _editerArticle(context, ref, categories, a),
            ),
        ],
      ],
    );
  }

  Future<void> _editerArticle(BuildContext context, WidgetRef ref, List<Categorie> categories, Article? a) async {
    final nom = TextEditingController(text: a?.nom ?? '');
    final prix = TextEditingController(text: a == null ? '' : '${a.prixVente}');
    final seuil = TextEditingController(text: '${a?.seuilAlerte ?? 0}');
    final casier = TextEditingController(text: '${a?.unitesParCasier ?? 0}');
    final stockInit = TextEditingController(text: '0');
    final photo = TextEditingController(text: a?.photoUrl ?? '');
    var cat = a?.idCategorie ?? categories.first.id;
    var type = a?.type ?? TypeArticle.revendu;
    var suivi = a?.suiviStock ?? true;
    var consigne = a?.consigne ?? false;
    final unite = TextEditingController(text: a?.type == TypeArticle.ingredient ? a!.unite : 'kg');
    final decimales = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    var actif = a?.actif ?? true;
    final chiffres = [FilteringTextInputFormatter.digitsOnly];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(a == null ? 'Nouvel article' : 'Modifier ${a.nom}'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: nom,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.nom))],
                  onChanged: (v) => cat = v!,
                ),
                TextField(
                  controller: prix,
                  keyboardType: TextInputType.number,
                  inputFormatters: chiffres,
                  decoration: const InputDecoration(labelText: 'Prix de vente TTC (F)'),
                ),
                const SizedBox(height: 8),
                SegmentedButton<TypeArticle>(
                  segments: const [
                    ButtonSegment(value: TypeArticle.revendu, label: Text('Revendu tel quel')),
                    ButtonSegment(value: TypeArticle.prepare, label: Text('Plat préparé')),
                    ButtonSegment(value: TypeArticle.ingredient, label: Text('Ingrédient')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setState(() => type = v.first),
                ),
                if (type == TypeArticle.ingredient)
                  TextField(
                    controller: unite,
                    decoration: const InputDecoration(labelText: 'Unité (kg, pièce, litre, portion…)'),
                  ),
                if (type == TypeArticle.prepare && (a?.aRecette ?? false))
                  const ListTile(
                    leading: Icon(Icons.menu_book_rounded),
                    title: Text('Géré par fiche technique'),
                    subtitle: Text('Les portions sont calculées à partir du stock des ingrédients.'),
                  )
                else if (type != TypeArticle.ingredient)
                  SwitchListTile(
                    title: const Text('Suivre le stock'),
                    subtitle: Text(type == TypeArticle.prepare ? 'en portions disponibles' : 'à l’unité'),
                    value: suivi,
                    onChanged: (v) => setState(() => suivi = v),
                  ),
                if (type == TypeArticle.revendu)
                  SwitchListTile(
                    title: const Text('Bouteille consignée'),
                    subtitle: const Text('Suivre les vides à rendre au fournisseur'),
                    value: consigne,
                    onChanged: (v) => setState(() => consigne = v),
                  ),
                if (suivi || type == TypeArticle.ingredient) ...[
                  TextField(
                    controller: seuil,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimales,
                    decoration: const InputDecoration(labelText: 'Seuil d’alerte'),
                  ),
                  if (type == TypeArticle.revendu)
                    TextField(
                      controller: casier,
                      keyboardType: TextInputType.number,
                      inputFormatters: chiffres,
                      decoration: const InputDecoration(labelText: 'Unités par casier (12, 24…)'),
                    ),
                  if (a == null)
                    TextField(
                      controller: stockInit,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimales,
                      decoration: const InputDecoration(labelText: 'Stock initial'),
                    ),
                ],
                TextField(
                  controller: photo,
                  decoration: const InputDecoration(labelText: 'Adresse de la photo (facultatif)'),
                ),
                SwitchListTile(
                  title: const Text('Actif (visible au menu)'),
                  value: actif,
                  onChanged: (v) => setState(() => actif = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final nouveau = Article(
      id: a?.id ?? '',
      nom: nom.text.trim(),
      idCategorie: cat,
      prixVente: int.tryParse(prix.text) ?? 0,
      type: type,
      unite: type == TypeArticle.ingredient
          ? (unite.text.trim().isEmpty ? 'unité' : unite.text.trim())
          : (type == TypeArticle.revendu ? 'bouteille' : 'portion'),
      seuilAlerte: lireDecimal(seuil.text) ?? 0,
      disponible: a?.disponible ?? true,
      actif: actif,
      suiviStock: type == TypeArticle.ingredient || suivi,
      consigne: type == TypeArticle.revendu && consigne,
      unitesParCasier: int.tryParse(casier.text) ?? 0,
      ordre: a?.ordre ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      photoUrl: photo.text.trim(),
    );
    await essayer(
      context,
      () => ref
          .read(adminServiceProvider)
          .enregistrerArticle(
            ref.read(acteurProvider)!,
            nouveau,
            ancien: a,
            stockInitial: lireDecimal(stockInit.text) ?? 0,
          ),
      succes: 'Article enregistré',
    );
  }

  /// Fiche technique d'un plat : ingrédients et quantités par portion.
  Future<void> _editerRecette(BuildContext context, WidgetRef ref, Article plat, List<Article> articles) async {
    final existante = ref.read(recettesProvider).value?[plat.id];
    final choix = articles
        .where((a) => a.id != plat.id && (a.type == TypeArticle.ingredient || a.type == TypeArticle.revendu))
        .toList();
    final lignes = <(String?, TextEditingController)>[
      for (final i in existante?.ingredients ?? const <Ingredient>[])
        (i.idArticle, TextEditingController(text: '${i.quantite}'.replaceAll('.', ','))),
    ];
    if (lignes.isEmpty) lignes.add((null, TextEditingController()));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Fiche technique : ${plat.nom}'),
          content: SizedBox(
            width: 520,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text('Ingrédients pour UNE portion. Chaque vente les retire du stock.'),
                const SizedBox(height: 12),
                for (var i = 0; i < lignes.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: lignes[i].$1,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Ingrédient'),
                            items: [
                              for (final a in choix)
                                DropdownMenuItem(value: a.id, child: Text('${a.nom} (${a.unite})')),
                            ],
                            onChanged: (v) => setState(() => lignes[i] = (v, lignes[i].$2)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lignes[i].$2,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Quantité',
                              suffixText: choix.where((a) => a.id == lignes[i].$1).firstOrNull?.unite,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Retirer',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => lignes.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un ingrédient'),
                    onPressed: () => setState(() => lignes.add((null, TextEditingController()))),
                  ),
                ),
                const Text(
                  'Pour revenir aux « portions du jour » saisies chaque matin, retirez tous les ingrédients.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final ingredients = [
      for (final (id, ctrl) in lignes)
        if (id != null && (lireDecimal(ctrl.text) ?? 0) > 0)
          Ingredient(
            idArticle: id,
            nom: choix.firstWhere((a) => a.id == id).nom,
            quantite: lireDecimal(ctrl.text)!,
            unite: choix.firstWhere((a) => a.id == id).unite,
          ),
    ];
    await essayer(
      context,
      () => ref.read(adminServiceProvider).enregistrerRecette(ref.read(acteurProvider)!, plat, ingredients),
      succes: ingredients.isEmpty ? 'Plat repassé en portions du jour' : 'Fiche technique enregistrée',
    );
  }
}

// -------------------------------------------------------------------- Tables

class _Tables extends ConsumerWidget {
  const _Tables();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider).value ?? const [];
    final tables = ref.watch(tablesProvider).value ?? const [];
    final acteur = ref.watch(acteurProvider)!;
    final svc = ref.read(adminServiceProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const EnTetePage(
          titre: 'Tables et zones',
          description: 'Salle, terrasse, VIP… Touchez une table pour la désactiver ou la réactiver.',
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Zone'),
              onPressed: () async {
                final nom = await demanderTexte(context, 'Nouvelle zone', label: 'Salle, terrasse, VIP…');
                if (nom == null || !context.mounted) return;
                await essayer(context, () => svc.enregistrerZone(acteur, nom: nom, ordre: zones.length));
              },
            ),
          ],
        ),
        for (final z in zones) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Text(z.nom, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Table'),
                  onPressed: () async {
                    final num = await demanderTexte(context, 'Nouvelle table (${z.nom})', label: 'Numéro ou nom');
                    if (num == null || !context.mounted) return;
                    if (tables.any((t) => t.numero == num)) {
                      afficherMessage(context, 'La table $num existe déjà', erreur: true);
                      return;
                    }
                    await essayer(context, () => svc.enregistrerTable(acteur, numero: num, idZone: z.id));
                  },
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tables.where((t) => t.idZone == z.id))
                InputChip(
                  label: Text('Table ${t.numero}'),
                  selected: t.active,
                  showCheckmark: false,
                  onPressed: () async {
                    if (t.statut != StatutTable.libre) {
                      afficherMessage(context, 'Table occupée', erreur: true);
                      return;
                    }
                    final ok = await confirmer(
                      context,
                      'Table ${t.numero}',
                      t.active ? 'Désactiver cette table ?' : 'Réactiver cette table ?',
                    );
                    if (!ok || !context.mounted) return;
                    await essayer(
                      context,
                      () =>
                          svc.enregistrerTable(acteur, id: t.id, numero: t.numero, idZone: t.idZone, active: !t.active),
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ Employés

/// Comptes de l'équipe : seul l'administrateur connecté en ligne peut
/// créer, modifier ou supprimer un compte (vérifié par le serveur).
class _Employes extends ConsumerWidget {
  const _Employes();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final employes = ref.watch(employesProvider).value ?? const [];
    final droits = ref.watch(droitsAdminProvider);
    final moi = ref.watch(utilisateurProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const EnTetePage(
          titre: 'Comptes de l’équipe',
          description:
              'Vous seul créez, modifiez ou supprimez les comptes. Chaque employé a un code personnel de 6 à 10 chiffres.',
        ),
        if (!droits)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: PanneauCaisse(
              couleur: p.occupee.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: p.occupee),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gestion des comptes indisponible hors ligne : reconnectez-vous quand internet est revenu.',
                      style: AppTypo.etiquette(p.texte, taille: 14, poids: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Nouveau compte'),
            onPressed: droits ? () => _editer(context, ref, null) : null,
          ),
        ),
        const SizedBox(height: 12),
        for (final e in employes)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: e.actif ? identite.secondaire : p.bordure,
                child: Text(e.nom.characters.first, style: AppTypo.titre(Colors.white, taille: 16)),
              ),
              title: Text(e.nom + (e.id == moi?.id ? ' (vous)' : ''), style: TextStyle(color: e.actif ? null : p.texteDiscret)),
              subtitle: Text('${e.role.libelle}${e.actif ? '' : ' · désactivé'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: droits ? () => _editer(context, ref, e) : null,
                  ),
                  IconButton(
                    tooltip: 'Supprimer le compte',
                    icon: Icon(Icons.delete_outline_rounded, color: droits && e.id != moi?.id ? p.erreur : null),
                    onPressed: droits && e.id != moi?.id ? () => _supprimer(context, ref, e) : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref, Employe e) async {
    final ok = await confirmer(
      context,
      'Supprimer le compte de ${e.nom} ?',
      '${e.nom} ne pourra plus se connecter. Son nom reste dans l’historique (factures, journal).',
    );
    if (!ok || !context.mounted) return;
    await essayer(context, () => ref.read(serveurAppareilsProvider).supprimerEmploye(e.id), succes: 'Compte supprimé');
  }

  Future<void> _editer(BuildContext context, WidgetRef ref, Employe? e) async {
    final nom = TextEditingController(text: e?.nom ?? '');
    final pin = TextEditingController();
    final pin2 = TextEditingController();
    var role = e?.role ?? Role.serveuse;
    var actif = e?.actif ?? true;
    String? erreur;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(e == null ? 'Nouveau compte' : 'Modifier ${e.nom}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom')),
                const SizedBox(height: 8),
                DropdownButtonFormField<Role>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: [for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.libelle))],
                  onChanged: (v) => role = v!,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: pinMax,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: e == null ? 'Code personnel (6 à 10 chiffres)' : 'Nouveau code (laisser vide pour garder)',
                  ),
                ),
                TextField(
                  controller: pin2,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: pinMax,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Confirmer le code'),
                ),
                if (e != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compte actif'),
                    subtitle: const Text('Désactivé : ne peut plus se connecter'),
                    value: actif,
                    onChanged: (v) => setState(() => actif = v),
                  ),
                if (erreur != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(erreur!, style: TextStyle(color: context.pal.erreur, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final code = pin.text;
                String? err;
                if (nom.text.trim().length < 2) {
                  err = 'Indiquez le nom.';
                } else if (e == null && code.isEmpty) {
                  err = 'Choisissez un code personnel.';
                } else if (code.isNotEmpty) {
                  err = verifierFormatPin(code) ?? (code != pin2.text ? 'Les deux codes ne correspondent pas.' : null);
                }
                if (err != null) {
                  setState(() => erreur = err);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final serveur = ref.read(serveurAppareilsProvider);
    await essayer(
      context,
      () => e == null
          ? serveur.creerEmploye(nom: nom.text, role: role, pin: pin.text)
          : serveur.modifierEmploye(
              e.id,
              nom: nom.text.trim() == e.nom ? null : nom.text,
              role: role == e.role ? null : role,
              actif: actif == e.actif ? null : actif,
              pin: pin.text.isEmpty ? null : pin.text,
            ),
      succes: e == null ? 'Compte créé' : 'Compte modifié',
    );
  }
}

// ---------------------------------------------------------------- Paramètres

class _Parametres extends ConsumerStatefulWidget {
  const _Parametres();
  @override
  ConsumerState<_Parametres> createState() => _ParametresState();
}

class _ParametresState extends ConsumerState<_Parametres> {
  Restaurant? _r;
  final _c = <String, TextEditingController>{};
  bool _tva = false;

  TextEditingController _ctrl(String k, String v) => _c.putIfAbsent(k, () => TextEditingController(text: v));

  @override
  Widget build(BuildContext context) {
    final r = _r ??= ref.watch(restaurantProvider).value;
    if (r == null) return const Chargement();
    if (_c.isEmpty) _tva = r.soumisTva;
    Widget champ(String k, String label, String v, {bool nombre = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _ctrl(k, v),
        keyboardType: nombre ? TextInputType.number : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const EnTetePage(
          titre: 'Paramètres',
          description: 'Identité du restaurant, mentions du ticket, TVA, déconnexion automatique et dépenses.',
        ),
        champ('nom', 'Nom du restaurant', r.nom),
        champ('adresse', 'Adresse', r.adresse),
        champ('telephone', 'Téléphone', r.telephone),
        champ('logo', 'Adresse du logo (image)', r.logoUrl),
        champ('mentions', 'Mentions sur la facture (RCCM, NCC…)', r.mentionsFacture),
        champ('message', 'Message de bas de ticket', r.messageBasTicket),
        champ('deconnexion', 'Déconnexion automatique (minutes)', '${r.deconnexionMinutes}', nombre: true),
        SwitchListTile(
          title: const Text('Soumis à la TVA'),
          subtitle: const Text('Les prix du menu sont saisis TTC'),
          value: _tva,
          onChanged: (v) => setState(() => _tva = v),
        ),
        if (_tva) champ('tva', 'Taux de TVA (%)', '${r.tauxTva}', nombre: true),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => essayer(
            context,
            () => ref
                .read(adminServiceProvider)
                .enregistrerParametres(
                  ref.read(acteurProvider)!,
                  Restaurant(
                    id: r.id,
                    nom: _c['nom']!.text.trim(),
                    adresse: _c['adresse']!.text.trim(),
                    telephone: _c['telephone']!.text.trim(),
                    logoUrl: _c['logo']!.text.trim(),
                    mentionsFacture: _c['mentions']!.text.trim(),
                    messageBasTicket: _c['message']!.text.trim(),
                    deconnexionMinutes: int.tryParse(_c['deconnexion']!.text) ?? 5,
                    soumisTva: _tva,
                    tauxTva: double.tryParse(_c['tva']?.text.replaceAll(',', '.') ?? '') ?? r.tauxTva,
                  ),
                ),
            succes: 'Paramètres enregistrés',
          ),
          child: const Text('Enregistrer'),
        ),
        const SizedBox(height: 24),
        Text('Dépenses', style: Theme.of(context).textTheme.titleMedium),
        const Text('Gaz, électricité, salaires, transport : pour calculer le bénéfice réel.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Saisir une dépense'),
          onPressed: () async {
            final cat = await showDialog<String>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('Catégorie'),
                children: [
                  for (final c in ['Gaz', 'Électricité', 'Eau', 'Salaires', 'Transport', 'Autre'])
                    SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c)),
                ],
              ),
            );
            if (cat == null || !context.mounted) return;
            final m = await demanderNombre(context, 'Dépense : $cat', label: 'Montant (F)');
            if (m == null || !context.mounted) return;
            await essayer(
              context,
              () => ref.read(adminServiceProvider).saisirDepense(ref.read(acteurProvider)!, categorie: cat, montant: m),
              succes: 'Dépense enregistrée',
            );
          },
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- Journal d'audit

class _Audit extends ConsumerStatefulWidget {
  const _Audit();
  @override
  ConsumerState<_Audit> createState() => _AuditState();
}

class _AuditState extends ConsumerState<_Audit> {
  String? _employe;
  String? _action;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditProvider);
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (liste) {
        final employes = liste.map((e) => e.employe).toSet().toList()..sort();
        final actions = liste.map((e) => e.action).toSet().toList()..sort();
        final f = liste
            .where((e) => (_employe == null || e.employe == _employe) && (_action == null || e.action == _action))
            .toList();
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: EnTetePage(
                titre: 'Journal d’audit',
                description:
                    'Toutes les actions sensibles, avec leur auteur, l’appareil et l’heure. Rien n’est jamais effacé.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 16,
                children: [
                  DropdownButton<String?>(
                    value: _employe,
                    hint: const Text('Tous les employés'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous les employés')),
                      for (final e in employes) DropdownMenuItem(value: e, child: Text(e)),
                    ],
                    onChanged: (v) => setState(() => _employe = v),
                  ),
                  DropdownButton<String?>(
                    value: _action,
                    hint: const Text('Toutes les actions'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Toutes les actions')),
                      for (final a in actions) DropdownMenuItem(value: a, child: Text(a)),
                    ],
                    onChanged: (v) => setState(() => _action = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: f.isEmpty
                  ? const Center(child: Text('Aucune action enregistrée'))
                  : ListView.builder(
                      itemCount: f.length,
                      itemBuilder: (context, i) {
                        final e = f[i];
                        return ListTile(
                          dense: true,
                          title: Text('${e.action} · ${e.detail}'),
                          subtitle: Text('${dateHeure(e.date)} · ${e.employe} · ${e.appareil}'),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
