import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/modeles.dart';
import '../theme/animated_widgets.dart';
import '../theme/app_theme.dart';
import '../theme/identite.dart';
import '../theme/motif.dart';

/// État visuel d'une table, déduit de sa session.
enum EtatTable { libre, occupee, addition }

EtatTable etatDe(SessionTable? s) =>
    s == null ? EtatTable.libre : (s.statut == StatutSession.ouverte ? EtatTable.occupee : EtatTable.addition);

extension EtatTableVisuel on EtatTable {
  String get libelle => switch (this) {
    EtatTable.libre => 'Libre',
    EtatTable.occupee => 'Occupée',
    EtatTable.addition => 'Addition',
  };

  IconData get icone => switch (this) {
    EtatTable.libre => Icons.event_seat_rounded,
    EtatTable.occupee => Icons.restaurant_rounded,
    EtatTable.addition => Icons.receipt_long_rounded,
  };

  Color couleur(AppPalette p) => switch (this) {
    EtatTable.libre => p.libre,
    EtatTable.occupee => p.occupee,
    EtatTable.addition => p.addition,
  };
}

String tagHeroTable(String idTable) => 'table-fond-$idTable';

/// Fond coloré d'une table (dégradé + motif tissé dans le coin).
///
/// C'est LUI qui vole entre le plan de salle et l'écran de commande : la
/// carte s'agrandit et devient l'en-tête. Le texte n'est pas dans le Hero
/// (il déborderait pendant le vol) ; chaque écran pose le sien par-dessus.
class FondTableHero extends StatelessWidget {
  final String idTable;
  final Color couleur;
  final BorderRadius rayon;

  const FondTableHero({super.key, required this.idTable, required this.couleur, required this.rayon});

  @override
  Widget build(BuildContext context) => Hero(
    tag: tagHeroTable(idTable),
    // Pendant le vol, couleur et arrondis se transforment en douceur.
    flightShuttleBuilder: (_, animation, direction, depuis, vers) {
      final a = (depuis.widget as Hero).child as _FondTable;
      final b = (vers.widget as Hero).child as _FondTable;
      final (debut, fin) = direction == HeroFlightDirection.push ? (a, b) : (b, a);
      return AnimatedBuilder(
        animation: animation,
        builder: (_, _) {
          final t = Curves.easeInOutCubic.transform(animation.value);
          return _FondTable(
            couleur: Color.lerp(debut.couleur, fin.couleur, t)!,
            rayon: BorderRadius.lerp(debut.rayon, fin.rayon, t)!,
            animeCouleur: false,
          );
        },
      );
    },
    child: _FondTable(couleur: couleur, rayon: rayon),
  );
}

class _FondTable extends StatelessWidget {
  final Color couleur;
  final BorderRadius rayon;
  final bool animeCouleur;
  const _FondTable({required this.couleur, required this.rayon, this.animeCouleur = true});

  /// Table libre : carte sombre sobre au liseré vert (les tables actives ressortent).
  bool get _sobre => couleur == identite.tableLibre;

  @override
  Widget build(BuildContext context) {
    final deco = _sobre
        ? BoxDecoration(
            borderRadius: rayon,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [identite.surfaceSombreElevee, identite.surfaceSombre],
            ),
            border: Border.all(color: couleur.withValues(alpha: 0.55), width: 1.4),
          )
        : BoxDecoration(
            borderRadius: rayon,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(couleur, Colors.white, 0.14)!, couleur, Color.lerp(couleur, identite.nuit, 0.40)!],
              stops: const [0, 0.48, 1],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          );
    final motif = ClipRRect(
      borderRadius: rayon,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              width: 120,
              height: 80,
              child: CustomPaint(painter: MotifPainter(couleur: _sobre ? couleur : Colors.white, opacite: _sobre ? 0.10 : 0.16)),
            ),
          ),
          // Liseré tissé en bas des tables actives.
          if (!_sobre) const Align(alignment: Alignment.bottomCenter, child: BandeKita(hauteur: 4)),
        ],
      ),
    );
    // Changement d'état (libre → occupée → addition) : transition 300 ms.
    return animeCouleur
        ? AnimatedContainer(duration: duree(context, 300), curve: Curves.easeOutCubic, decoration: deco, child: motif)
        : DecoratedBox(decoration: deco, child: motif);
  }
}

/// Carte de table du plan de salle, entièrement animée :
/// - couleur et lueur qui se transforment quand l'état change (300 ms) ;
/// - halo respirant + pastille « Addition » quand l'addition est demandée ;
/// - montant qui compte, enfoncement élastique au toucher ;
/// - fond partagé en Hero avec l'en-tête de l'écran de commande.
class AnimatedTableCard extends StatelessWidget {
  final TableResto table;
  final SessionTable? session;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const AnimatedTableCard({super.key, required this.table, this.session, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = session;
    final etat = etatDe(s);
    final couleur = etat.couleur(p);
    final rayon = BorderRadius.circular(identite.arrondi);
    return Semantics(
      container: true,
      button: true,
      label: 'Table ${table.numero}, ${etat.libelle}${s == null ? '' : ', ${fcfa(s.total)}, ${s.nomServeuse}'}',
      excludeSemantics: true,
      child: PulseAlertBadge(
        active: etat == EtatTable.addition,
        couleur: couleur,
        rayon: rayon,
        label: 'Addition',
        icone: Icons.notifications_active_rounded,
        child: BouncyTapWrapper(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: duree(context, 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: rayon,
              boxShadow: etat == EtatTable.libre
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))]
                  : AppOmbres.lueur(couleur, force: 1.1),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: FondTableHero(idTable: table.id, couleur: couleur, rayon: rayon),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: _ContenuCarte(table: table, session: s, etat: etat),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContenuCarte extends StatelessWidget {
  final TableResto table;
  final SessionTable? session;
  final EtatTable etat;
  const _ContenuCarte({required this.table, required this.session, required this.etat});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final libre = etat == EtatTable.libre;
    final texte = libre ? identite.texteSombre : Colors.white;
    final blancDoux = texte.withValues(alpha: 0.78);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Places : pleines = couverts annoncés.
            for (var i = 0; i < table.capacite.clamp(0, 8); i++)
              Container(
                margin: const EdgeInsets.only(right: 3),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (libre ? identite.tableLibre : Colors.white).withValues(alpha: s != null && i < s.couverts ? 0.95 : 0.40),
                ),
              ),
            const Spacer(),
            Icon(etat.icone, size: 18, color: libre ? identite.tableLibre : blancDoux),
          ],
        ),
        const Spacer(),
        Text(table.numero, style: AppTypo.chiffres(AppTypo.marque(texte, taille: 40, poids: FontWeight.w800))),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: duree(context, 300),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          child: s == null
              ? Row(
                  key: const ValueKey('libre'),
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: identite.tableLibre, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Libre', style: AppTypo.etiquette(blancDoux, taille: 14)),
                  ],
                )
              : Column(
                  key: ValueKey('occ-${s.id}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmoothCounterText(s.total, style: AppTypo.montant(Colors.white, taille: 18)),
                    Text(
                      '${heure(s.ouverture)} · ${s.nomServeuse}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypo.chiffres(AppTypo.etiquette(blancDoux, taille: 12, poids: FontWeight.w500)),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
