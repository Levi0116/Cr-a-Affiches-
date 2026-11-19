import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../theme/motif.dart';
import '../../widgets/barre_etat.dart';
import 'factures_ardoises.dart';
import 'journee_caisse.dart';
import 'tables_ouvertes.dart';

/// ============================================================================
///  CAISSE (section 3.2) — ambiance claire « crème Amani », poste fixe
/// ============================================================================
///
/// En-tête : logo, état de la journée et indicateurs en direct (encaissé,
/// en cours, additions en attente qui pulsent). Quatre sections : tables
/// ouvertes (ticket + encaissement), factures du jour, ardoises, journée
/// (ouverture / clôture avec comptage des billets).
class EcranCaisse extends ConsumerStatefulWidget {
  /// false quand l'écran est intégré dans l'espace administrateur.
  final bool avecBarre;
  const EcranCaisse({super.key, this.avecBarre = true});

  @override
  ConsumerState<EcranCaisse> createState() => _EcranCaisseState();
}

enum _Section { tables, factures, ardoises, journee }

class _EcranCaisseState extends ConsumerState<EcranCaisse> {
  _Section _section = _Section.tables;
  String? _selection;

  @override
  Widget build(BuildContext context) {
    // Alerte sonore discrète quand une nouvelle addition est demandée.
    ref.listen(sessionsEnCoursProvider, (avant, apres) {
      int n(AsyncValue<List<SessionTable>>? v) =>
          v?.value?.where((s) => s.statut == StatutSession.addition).length ?? 0;
      if (n(apres) > n(avant)) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
      }
    });
    final p = context.pal;
    final corps = switch (_section) {
      _Section.tables => VueTablesOuvertes(selection: _selection, onSelection: (id) => setState(() => _selection = id)),
      _Section.factures => const VueFacturesDuJour(),
      _Section.ardoises => const VueArdoises(),
      _Section.journee => const VueJournee(),
    };
    return Theme(
      data: AppTheme.clair,
      child: Scaffold(
        backgroundColor: p.fond,
        body: SafeArea(
          child: Column(
            children: [
              _EnTeteCaisse(avecBarre: widget.avecBarre),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _Selecteur(section: _section, onSection: (s) => setState(() => _section = s)),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: duree(context, 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(_section), child: corps),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================= En-tête

class _EnTeteCaisse extends ConsumerWidget {
  final bool avecBarre;
  const _EnTeteCaisse({required this.avecBarre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final resto = ref.watch(restaurantProvider).value;
    final journee = ref.watch(journeeOuverteProvider).value;
    final sessions = ref.watch(sessionsEnCoursProvider).value ?? const <SessionTable>[];
    final e = ref.watch(utilisateurProvider);
    final enCours = sessions.fold(0, (s, x) => s + x.total);
    final attente = sessions.where((s) => s.statut != StatutSession.ouverte).length;
    final etroit = MediaQuery.sizeOf(context).width < 900;

    final indicateurs = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Indicateur(
          icone: journee == null ? Icons.lock_rounded : Icons.savings_rounded,
          titre: journee == null ? 'Caisse fermée' : 'Encaissé',
          valeur: journee?.totalEncaisse,
          couleur: journee == null ? p.occupee : p.libre,
        ),
        _Indicateur(icone: Icons.table_restaurant_rounded, titre: 'En cours', valeur: enCours, couleur: p.texte),
        PulseGlow(
          active: attente > 0,
          couleur: p.addition,
          rayon: BorderRadius.circular(identite.arrondi),
          child: _Indicateur(
            icone: Icons.notifications_active_rounded,
            titre: 'À encaisser',
            nombre: attente,
            couleur: attente > 0 ? p.addition : p.texteDiscret,
            accent: attente > 0,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (avecBarre) ...[
                Hero(
                  tag: 'logo',
                  child: LogoResto(nom: resto?.nom ?? '', taille: 52),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Caisse', style: AppTypo.titre(p.texte, taille: 26)),
                    Text(
                      resto?.nom ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypo.etiquette(p.texteSecondaire, taille: 14, poids: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (!etroit) ...[indicateurs, const SizedBox(width: 14)],
              IndicateurConnexion(compact: etroit),
              if (avecBarre && e != null) ...[const SizedBox(width: 10), _Utilisateur(nom: e.nom)],
            ],
          ),
          if (etroit) ...[const SizedBox(height: 12), indicateurs],
        ],
      ),
    );
  }
}

class _Indicateur extends StatelessWidget {
  final IconData icone;
  final String titre;
  final int? valeur;
  final int? nombre;
  final Color couleur;
  final bool accent;
  const _Indicateur({
    required this.icone,
    required this.titre,
    required this.couleur,
    this.valeur,
    this.nombre,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final style = AppTypo.montant(p.texte, taille: 17);
    return AnimatedContainer(
      duration: duree(context, 300),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: accent ? Color.alphaBlend(couleur.withValues(alpha: 0.10), p.surface) : p.surface,
        borderRadius: BorderRadius.circular(identite.arrondi),
        border: Border.all(color: accent ? couleur.withValues(alpha: 0.5) : p.bordure),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 20, color: couleur),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: AppTypo.etiquette(p.texteSecondaire, taille: 12)),
              if (valeur != null)
                SmoothCounterText(valeur!, style: style)
              else if (nombre != null)
                SmoothCounterText.nombre(nombre!, style: style),
            ],
          ),
        ],
      ),
    );
  }
}

class _Utilisateur extends ConsumerWidget {
  final String nom;
  const _Utilisateur({required this.nom});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    return Semantics(
      container: true,
      button: true,
      label: '$nom, changer d’utilisateur',
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          ref.read(utilisateurProvider.notifier).deconnecter();
        },
        child: Container(
          height: 52,
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: p.bordure),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: identite.secondaire,
                child: Text(nom.characters.first, style: AppTypo.titre(Colors.white, taille: 15)),
              ),
              const SizedBox(width: 8),
              Text(nom, style: AppTypo.etiquette(p.texte, taille: 15)),
              const SizedBox(width: 6),
              Icon(Icons.logout_rounded, size: 18, color: p.texteDiscret),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================ Sections

/// Sélecteur de sections : un indicateur glisse sous l'onglet actif.
/// Chaque onglet porte un compteur (ardoises, factures à encaisser…).
class _Selecteur extends ConsumerWidget {
  final _Section section;
  final ValueChanged<_Section> onSection;
  const _Selecteur({required this.section, required this.onSection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final sessions = ref.watch(sessionsEnCoursProvider).value ?? const <SessionTable>[];
    final factures = ref.watch(facturesDepuisProvider(debutJour())).value ?? const <Facture>[];
    final ardoises = (ref.watch(ardoisesProvider).value ?? const <Ardoise>[]).where((a) => a.montantDu > 0).length;
    final journeeOuverte = ref.watch(journeeOuverteProvider).value != null;
    final items = [
      (_Section.tables, Icons.table_restaurant_rounded, 'Tables', sessions.length),
      (_Section.factures, Icons.receipt_long_rounded, 'Factures', factures.length),
      (_Section.ardoises, Icons.menu_book_rounded, 'Ardoises', ardoises),
      (_Section.journee, journeeOuverte ? Icons.lock_open_rounded : Icons.lock_rounded, 'Journée', null),
    ];
    final index = items.indexWhere((x) => x.$1 == section);
    return LayoutBuilder(
      builder: (context, c) {
        final largeurOnglet = (c.maxWidth.clamp(0, 760) - 14) / items.length;
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: largeurOnglet * items.length + 14, // 2 × 6 de marge + 2 × 1 de bordure
            height: 64,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(identite.arrondi),
              border: Border.all(color: p.bordure),
              boxShadow: AppOmbres.douce(p, force: 0.5),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: duree(context, 320),
                  curve: Curves.easeOutCubic,
                  left: index * largeurOnglet,
                  top: 0,
                  bottom: 0,
                  width: largeurOnglet,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: degradePrincipal(identite.secondaire),
                      borderRadius: BorderRadius.circular(identite.arrondi * 0.75),
                      boxShadow: AppOmbres.lueur(identite.secondaire, force: 0.6),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (s, icone, nom, compte) in items)
                      SizedBox(
                        width: largeurOnglet,
                        child: Semantics(
                          container: true,
                          button: true,
                          selected: s == section,
                          label: '$nom${compte == null ? '' : ', $compte'}',
                          excludeSemantics: true,
                          child: BouncyTapWrapper(
                            onTap: () => onSection(s),
                            child: _Onglet(icone: icone, nom: nom, compte: compte, actif: s == section),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Onglet extends StatelessWidget {
  final IconData icone;
  final String nom;
  final int? compte;
  final bool actif;
  const _Onglet({required this.icone, required this.nom, required this.compte, required this.actif});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = actif ? Colors.white : p.texteSecondaire;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 20, color: c),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: duree(context, 250),
                style: AppTypo.etiquette(c, taille: 15, poids: FontWeight.w700),
                child: Text(nom),
              ),
              if (compte != null && compte! > 0) ...[
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: duree(context, 250),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: actif ? Colors.white.withValues(alpha: 0.22) : p.principale.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SmoothCounterText.nombre(
                    compte!,
                    style: AppTypo.etiquette(actif ? Colors.white : p.principale, taille: 12, poids: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
