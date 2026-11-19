import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/calculs.dart';
import '../../core/format.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';

/// Pavé d'encaissement plein écran (caisse tactile ou clavier).
///
/// - Pavé numérique XXL : touches de 64 dp, enfoncement élastique.
/// - Billets FCFA qui **s'additionnent** : le client tend 5 000 + 2 000,
///   on touche 5 000 puis 2 000 — exactement comme on compte en main.
/// - Montants rapides calculés (exact, arrondis au billet supérieur).
/// - Clavier physique accepté : chiffres, retour arrière, Entrée.
/// - Monnaie à rendre en grand, qui compte jusqu'à sa valeur.
///
/// Retourne le montant reçu, ou null si annulé. Avec [partiel], un montant
/// inférieur est accepté (remboursement partiel d'une ardoise).
Future<int?> demanderEncaissement(
  BuildContext context, {
  required int aPayer,
  String titre = 'Encaissement',
  String? sousTitre,
  bool partiel = false,
  String libelleBouton = 'Valider le paiement',
}) => showGeneralDialog<int>(
  context: context,
  // Pas de fermeture par un tap à côté : la saisie serait perdue.
  // Fermeture par la croix ou la touche Échap.
  barrierDismissible: false,
  barrierLabel: 'Fermer',
  barrierColor: Colors.black.withValues(alpha: 0.45),
  transitionDuration: duree(context, 320),
  pageBuilder: (_, _, _) => _PaveEncaissement(
    aPayer: aPayer,
    titre: titre,
    sousTitre: sousTitre,
    partiel: partiel,
    libelleBouton: libelleBouton,
  ),
  transitionBuilder: (_, a, _, child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: c,
      child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(c), child: child),
    );
  },
);

class _PaveEncaissement extends StatefulWidget {
  final int aPayer;
  final String titre;
  final String? sousTitre;
  final bool partiel;
  final String libelleBouton;
  const _PaveEncaissement({
    required this.aPayer,
    required this.titre,
    required this.sousTitre,
    required this.partiel,
    required this.libelleBouton,
  });

  @override
  State<_PaveEncaissement> createState() => _PaveEncaissementState();
}

class _PaveEncaissementState extends State<_PaveEncaissement> {
  int _recu = 0;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get _valide => widget.partiel ? _recu > 0 : _recu >= widget.aPayer && _recu > 0;

  void _chiffre(String c) {
    final texte = _recu == 0 ? c.replaceFirst(RegExp('^0+'), '') : '$_recu$c';
    if (texte.isEmpty || texte.length > 9) return;
    setState(() => _recu = int.parse(texte));
  }

  void _effacerUn() => setState(() => _recu = _recu ~/ 10);
  void _ajouter(int v) => setState(() => _recu = (_recu + v).clamp(0, 999999999));
  void _poser(int v) => setState(() => _recu = v);

  void _valider() {
    if (!_valide) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _recu);
  }

  KeyEventResult _clavier(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final c = e.character;
    if (c != null && RegExp(r'^\d$').hasMatch(c)) {
      _chiffre(c);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace) {
      _effacerUn();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _valider();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final large = MediaQuery.sizeOf(context).width >= 860;
    final monnaie = _recu - widget.aPayer;
    final suffisant = monnaie >= 0;

    final resume = _Resume(aPayer: widget.aPayer, recu: _recu, monnaie: monnaie, partiel: widget.partiel);
    final billets = _Billets(aPayer: widget.aPayer, onAjouter: _ajouter, onPoser: _poser, onEffacer: () => _poser(0));
    final pave = _Pave(onChiffre: _chiffre, onEffacer: _effacerUn);
    final bouton = GradientActionButton(
      label: widget.libelleBouton,
      icone: Icons.check_rounded,
      hauteur: 64,
      couleur: suffisant || widget.partiel ? p.libre : null,
      onPressed: _valide ? _valider : null,
    );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      includeSemantics: false,
      onKeyEvent: _clavier,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: large ? 960 : 520),
              child: Material(
                color: p.fond,
                borderRadius: BorderRadius.circular(identite.arrondi * 1.5),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.titre, style: AppTypo.titre(p.texte, taille: 24)),
                                if (widget.sousTitre != null)
                                  Text(widget.sousTitre!, style: AppTypo.etiquette(p.texteSecondaire, taille: 14)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Annuler (Échap)',
                            iconSize: 28,
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close_rounded, color: p.texteSecondaire),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (large)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [resume, const SizedBox(height: 16), billets],
                              ),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(width: 330, child: Column(children: [pave, const SizedBox(height: 14), bouton])),
                          ],
                        )
                      else ...[
                        resume,
                        const SizedBox(height: 14),
                        billets,
                        const SizedBox(height: 14),
                        pave,
                        const SizedBox(height: 14),
                        bouton,
                      ],
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

class _Resume extends StatelessWidget {
  final int aPayer;
  final int recu;
  final int monnaie;
  final bool partiel;
  const _Resume({required this.aPayer, required this.recu, required this.monnaie, required this.partiel});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final suffisant = monnaie >= 0;
    final (String libelle, Color couleur, IconData icone) = recu == 0
        ? ('Saisissez le montant reçu', p.texteDiscret, Icons.keyboard_rounded)
        : suffisant
        ? ('Monnaie à rendre', p.libre, Icons.check_circle_rounded)
        : (partiel ? 'Reste dû après ce versement' : 'Il manque', partiel ? p.addition : p.erreur, Icons.error_rounded);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Case(titre: partiel ? 'Dû' : 'À payer', valeur: aPayer, couleur: p.texte),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Case(titre: 'Reçu', valeur: recu, couleur: p.principale, direct: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: duree(context, 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(identite.arrondi),
            border: Border.all(color: couleur.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icone, color: couleur, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: duree(context, 200),
                  child: Text(
                    libelle,
                    key: ValueKey(libelle),
                    style: AppTypo.etiquette(couleur, taille: 16, poids: FontWeight.w700),
                  ),
                ),
              ),
              if (recu > 0) SmoothCounterText(monnaie.abs(), style: AppTypo.montant(couleur, taille: 38)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Case extends StatelessWidget {
  final String titre;
  final int valeur;
  final Color couleur;
  final bool direct;
  const _Case({required this.titre, required this.valeur, required this.couleur, this.direct = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final style = AppTypo.montant(couleur, taille: 30);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(identite.arrondi),
        border: Border.all(color: direct ? couleur.withValues(alpha: 0.5) : p.bordure, width: direct ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: AppTypo.etiquette(p.texteSecondaire, taille: 13)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            // La saisie s'affiche immédiatement (pas de compteur animé : la
            // caissière doit voir ce qu'elle tape, sans délai).
            child: direct ? Text(fcfa(valeur), style: style) : SmoothCounterText(valeur, style: style),
          ),
        ],
      ),
    );
  }
}

class _Billets extends StatelessWidget {
  final int aPayer;
  final ValueChanged<int> onAjouter;
  final ValueChanged<int> onPoser;
  final VoidCallback onEffacer;
  const _Billets({required this.aPayer, required this.onAjouter, required this.onPoser, required this.onEffacer});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rapides = montantsRapides(aPayer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Montant tendu', style: AppTypo.etiquette(p.texteSecondaire, taille: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, m) in rapides.indexed)
              StaggeredEntrance(
                index: i,
                child: _Puce(
                  texte: i == 0 ? 'Exact · ${fcfa(m)}' : fcfa(m),
                  couleur: i == 0 ? p.libre : p.texte,
                  onTap: () => onPoser(m),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Ajouter un billet', style: AppTypo.etiquette(p.texteSecondaire, taille: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, b) in const [500, 1000, 2000, 5000, 10000].indexed)
              StaggeredEntrance(
                index: i + 3,
                child: _Billet(valeur: b, onTap: () => onAjouter(b)),
              ),
            _Puce(texte: 'Effacer', couleur: p.erreur, icone: Icons.backspace_outlined, onTap: onEffacer),
          ],
        ),
      ],
    );
  }
}

/// Billet stylisé, teinté selon sa valeur (repère visuel rapide).
class _Billet extends StatelessWidget {
  final int valeur;
  final VoidCallback onTap;
  const _Billet({required this.valeur, required this.onTap});

  Color get _teinte => switch (valeur) {
    500 => const Color(0xFF6D8B3A),
    1000 => const Color(0xFF8A5A2B),
    2000 => const Color(0xFF2F6E8E),
    5000 => const Color(0xFF7A4E9A),
    _ => const Color(0xFFB0472E),
  };

  @override
  Widget build(BuildContext context) {
    final c = _teinte;
    return Semantics(
      container: true,
      button: true,
      label: 'Ajouter un billet de ${fcfa(valeur)}',
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: onTap,
        child: Container(
          width: 104,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: [Color.lerp(c, Colors.white, 0.15)!, c]),
            boxShadow: AppOmbres.lueur(c, force: 0.6),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: -10,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14)),
                ),
              ),
              Center(child: Text('+ ${fcfa(valeur)}', style: AppTypo.montant(Colors.white, taille: 15))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Puce extends StatelessWidget {
  final String texte;
  final Color couleur;
  final IconData? icone;
  final VoidCallback onTap;
  const _Puce({required this.texte, required this.couleur, required this.onTap, this.icone});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      container: true,
      button: true,
      label: texte,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: couleur.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[Icon(icone, color: couleur, size: 18), const SizedBox(width: 6)],
              Text(texte, style: AppTypo.chiffres(AppTypo.etiquette(couleur, taille: 15, poids: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pave extends StatelessWidget {
  final ValueChanged<String> onChiffre;
  final VoidCallback onEffacer;
  const _Pave({required this.onChiffre, required this.onEffacer});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    const touches = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', '⌫'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        for (final t in touches)
          Semantics(
            container: true,
            button: true,
            label: t == '⌫' ? 'Effacer un chiffre' : t,
            excludeSemantics: true,
            child: BouncyTapWrapper(
              scale: 0.9,
              onTap: () => t == '⌫' ? onEffacer() : onChiffre(t),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t == '⌫' ? p.fond : p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.bordure),
                  boxShadow: t == '⌫' ? null : AppOmbres.douce(p, force: 0.5),
                ),
                child: t == '⌫'
                    ? Icon(Icons.backspace_outlined, color: p.texteSecondaire)
                    : Text(t, style: AppTypo.montant(p.texte, taille: 26, poids: FontWeight.w700)),
              ),
            ),
          ),
      ],
    );
  }
}
