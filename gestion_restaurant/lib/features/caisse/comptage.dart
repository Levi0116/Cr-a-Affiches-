import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/calculs.dart';
import '../../core/format.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../widgets/commun.dart';

/// Comptage de caisse par billets et pièces (ouverture et clôture).
///
/// Chaque coupure a ses touches − et + (56 dp) ; toucher le nombre permet
/// de le taper. Le total compte en direct ; si [theorique] est donné,
/// l'écart s'affiche (juste / manquant / excédent, avec icône et texte).
/// Un montant global peut aussi être saisi directement.
Future<int?> demanderComptage(
  BuildContext context, {
  required String titre,
  String? sousTitre,
  int? theorique,
  String libelleBouton = 'Valider',
}) => showGeneralDialog<int>(
  context: context,
  // Pas de fermeture par un tap à côté : la saisie serait perdue.
  // Fermeture par la croix ou la touche Échap.
  barrierDismissible: false,
  barrierLabel: 'Fermer',
  barrierColor: Colors.black.withValues(alpha: 0.45),
  transitionDuration: duree(context, 320),
  pageBuilder: (_, _, _) =>
      _Comptage(titre: titre, sousTitre: sousTitre, theorique: theorique, libelleBouton: libelleBouton),
  transitionBuilder: (_, a, _, child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: c,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(c),
        child: child,
      ),
    );
  },
);

class _Comptage extends StatefulWidget {
  final String titre;
  final String? sousTitre;
  final int? theorique;
  final String libelleBouton;
  const _Comptage({required this.titre, this.sousTitre, this.theorique, required this.libelleBouton});

  @override
  State<_Comptage> createState() => _ComptageState();
}

class _ComptageState extends State<_Comptage> {
  final _nombres = List<int>.filled(coupuresFcfa.length, 0);
  int? _global; // montant saisi directement, prioritaire sur le détail

  int get _total => _global ?? totalComptage(_nombres);

  void _changer(int i, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _global = null;
      _nombres[i] = (_nombres[i] + delta).clamp(0, 99999);
    });
  }

  Future<void> _taper(int i) async {
    final c = coupuresFcfa[i];
    final n = await demanderNombre(
      context,
      '${c.billet ? 'Billets' : 'Pièces'} de ${fcfa(c.valeur)}',
      label: 'Nombre',
      initial: _nombres[i],
    );
    if (n == null || n < 0) return;
    setState(() {
      _global = null;
      _nombres[i] = n;
    });
  }

  Future<void> _saisirGlobal() async {
    final n = await demanderNombre(context, 'Montant total', label: 'Montant (F)', initial: _total);
    if (n == null || n < 0) return;
    setState(() => _global = n);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final large = MediaQuery.sizeOf(context).width >= 860;
    final billets = [
      for (var i = 0; i < coupuresFcfa.length; i++)
        if (coupuresFcfa[i].billet) i,
    ];
    final pieces = [
      for (var i = 0; i < coupuresFcfa.length; i++)
        if (!coupuresFcfa[i].billet) i,
    ];

    Widget colonne(String titre, IconData icone, List<int> indices) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icone, size: 18, color: p.texteSecondaire),
            const SizedBox(width: 6),
            Text(titre, style: AppTypo.etiquette(p.texteSecondaire, taille: 14, poids: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        for (final (rang, i) in indices.indexed)
          StaggeredEntrance(
            index: rang,
            child: _LigneCoupure(
              coupure: coupuresFcfa[i],
              nombre: _nombres[i],
              grise: _global != null,
              onMoins: () => _changer(i, -1),
              onPlus: () => _changer(i, 1),
              onTaper: () => _taper(i),
            ),
          ),
      ],
    );

    // Clavier : Échap annule, Entrée valide.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
        const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.pop(context, _total),
      },
      child: Focus(
        autofocus: true,
        // Le Focus sert au clavier seulement : sans sémantique propre, sinon
        // il fusionne tout le contenu en un seul nœud pour les lecteurs d'écran.
        includeSemantics: false,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: large ? 980 : 520),
                child: Material(
                  color: p.fond,
                  borderRadius: BorderRadius.circular(identite.arrondi * 1.5),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.titre, style: AppTypo.marque(p.texte, taille: 28)),
                                  if (widget.sousTitre != null)
                                    Text(widget.sousTitre!, style: AppTypo.etiquette(p.texteSecondaire, taille: 14)),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _saisirGlobal,
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('Saisir le total'),
                            ),
                            IconButton(
                              tooltip: 'Annuler',
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close_rounded, color: p.texteSecondaire),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          child: large
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: colonne('Billets', Icons.payments_rounded, billets)),
                                    const SizedBox(width: 20),
                                    Expanded(child: colonne('Pièces', Icons.toll_rounded, pieces)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    colonne('Billets', Icons.payments_rounded, billets),
                                    const SizedBox(height: 16),
                                    colonne('Pièces', Icons.toll_rounded, pieces),
                                  ],
                                ),
                        ),
                      ),
                      _Pied(
                        total: _total,
                        theorique: widget.theorique,
                        global: _global != null,
                        libelleBouton: widget.libelleBouton,
                        onValider: () => Navigator.pop(context, _total),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LigneCoupure extends StatelessWidget {
  final Coupure coupure;
  final int nombre;
  final bool grise;
  final VoidCallback onMoins;
  final VoidCallback onPlus;
  final VoidCallback onTaper;
  const _LigneCoupure({
    required this.coupure,
    required this.nombre,
    required this.grise,
    required this.onMoins,
    required this.onPlus,
    required this.onTaper,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final actif = nombre > 0 && !grise;
    return AnimatedContainer(
      duration: duree(context, 220),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: actif ? Color.alphaBlend(p.principale.withValues(alpha: 0.06), p.surface) : p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: actif ? p.principale.withValues(alpha: 0.4) : p.bordure),
      ),
      child: Row(
        children: [
          Icon(coupure.billet ? Icons.payments_outlined : Icons.circle_outlined, size: 18, color: p.texteDiscret),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: Text(fcfa(coupure.valeur), style: AppTypo.montant(p.texte, taille: 16, poids: FontWeight.w700)),
          ),
          Expanded(
            child: Text(
              nombre == 0 ? '' : '= ${fcfa(nombre * coupure.valeur)}',
              style: AppTypo.chiffres(AppTypo.etiquette(p.texteSecondaire, taille: 13, poids: FontWeight.w500)),
            ),
          ),
          _Rond(icone: Icons.remove_rounded, label: 'Retirer', onTap: nombre > 0 ? onMoins : null),
          Semantics(
            container: true,
            button: true,
            label: '$nombre ${coupure.billet ? 'billets' : 'pièces'} de ${fcfa(coupure.valeur)}, toucher pour saisir',
            excludeSemantics: true,
            child: InkWell(
              onTap: onTaper,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 48,
                child: Center(child: RollingNumber(nombre, style: AppTypo.montant(p.texte, taille: 20))),
              ),
            ),
          ),
          _Rond(icone: Icons.add_rounded, label: 'Ajouter', plein: true, onTap: onPlus),
        ],
      ),
    );
  }
}

class _Rond extends StatelessWidget {
  final IconData icone;
  final String label;
  final bool plein;
  final VoidCallback? onTap;
  const _Rond({required this.icone, required this.label, required this.onTap, this.plein = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final actif = onTap != null;
    return Semantics(
      container: true,
      button: true,
      enabled: actif,
      label: label,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        scale: 0.86,
        onTap: onTap,
        child: AnimatedContainer(
          duration: duree(context, 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: plein ? p.principale : p.fond,
            border: Border.all(color: plein ? Colors.transparent : p.bordure),
          ),
          child: Icon(icone, color: plein ? Colors.white : (actif ? p.texte : p.texteDiscret)),
        ),
      ),
    );
  }
}

class _Pied extends StatelessWidget {
  final int total;
  final int? theorique;
  final bool global;
  final String libelleBouton;
  final VoidCallback onValider;
  const _Pied({
    required this.total,
    required this.theorique,
    required this.global,
    required this.libelleBouton,
    required this.onValider,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ecart = theorique == null ? null : total - theorique!;
    final (String txtEcart, Color cEcart, IconData iEcart) = switch (ecart) {
      null => ('', p.texte, Icons.check),
      0 => ('Caisse juste', p.libre, Icons.check_circle_rounded),
      < 0 => ('Manquant', p.erreur, Icons.trending_down_rounded),
      _ => ('Excédent', p.occupee, Icons.trending_up_rounded),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.bordure)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(global ? 'Total saisi' : 'Total compté', style: AppTypo.etiquette(p.texteSecondaire, taille: 13)),
              SmoothCounterText(total, style: AppTypo.montant(p.texte, taille: 32)),
            ],
          ),
          if (ecart != null)
            AnimatedContainer(
              duration: duree(context, 260),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cEcart.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cEcart.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iEcart, color: cEcart),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$txtEcart · théorique ${fcfa(theorique!)}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypo.chiffres(AppTypo.etiquette(cEcart, taille: 13, poids: FontWeight.w700)),
                        ),
                        SmoothCounterText(
                          ecart,
                          format: (v) => '${v > 0 ? '+' : ''}${fcfa(v)}',
                          style: AppTypo.montant(cEcart, taille: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          GradientActionButton(label: libelleBouton, icone: Icons.check_rounded, onPressed: onValider),
        ],
      ),
    );
  }
}
