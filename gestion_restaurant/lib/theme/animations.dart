import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import 'identite.dart';

/// Animations maison de l'application.
///
/// Toutes les durées passent par [duree] : elles respectent le réglage
/// [IdentiteVisuelle.vitesseAnimations] et l'option d'accessibilité
/// « réduire les animations » de l'appareil.
Duration duree(BuildContext context, int millisecondes) {
  final calme = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  if (calme || identite.vitesseAnimations <= 0) return Duration.zero;
  return Duration(milliseconds: (millisecondes / identite.vitesseAnimations).round());
}

bool animationsActives(BuildContext context) =>
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) && identite.vitesseAnimations > 0;

// ---------------------------------------------------------------- Montant

/// Montant qui « compte » jusqu'à sa nouvelle valeur (12 500 F → 13 200 F).
class MontantAnime extends StatefulWidget {
  final int montant;
  final TextStyle? style;
  final TextAlign? textAlign;
  const MontantAnime(this.montant, {super.key, this.style, this.textAlign});

  @override
  State<MontantAnime> createState() => _MontantAnimeState();
}

class _MontantAnimeState extends State<MontantAnime> {
  late int _depart = widget.montant;

  @override
  void didUpdateWidget(MontantAnime old) {
    super.didUpdateWidget(old);
    if (old.montant != widget.montant) _depart = old.montant;
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(widget.montant),
    tween: Tween(begin: _depart.toDouble(), end: widget.montant.toDouble()),
    duration: duree(context, 650),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text(fcfa(v.round()), style: widget.style, textAlign: widget.textAlign),
  );
}

// ------------------------------------------------------------------ Pression

/// Effet d'appui : le bouton s'enfonce légèrement puis rebondit, avec un
/// petit retour haptique sur tablette.
class Pression extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double echelle;
  const Pression({super.key, required this.child, this.onTap, this.onLongPress, this.echelle = 0.94});

  @override
  State<Pression> createState() => _PressionState();
}

class _PressionState extends State<Pression> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 380),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _relacher() {
    if (!mounted) return;
    _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final actif = widget.onTap != null || widget.onLongPress != null;
    final anim = animationsActives(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: actif && anim ? (_) => _c.forward() : null,
      onTapUp: actif && anim ? (_) => _relacher() : null,
      onTapCancel: actif && anim ? _relacher : null,
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              if (anim && !_c.isAnimating && _c.value == 0) {
                _c.forward().then((_) => _relacher());
              }
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          // Rebond élastique au relâchement.
          final t = _c.status == AnimationStatus.reverse
              ? Curves.elasticIn.transform(_c.value)
              : Curves.easeOut.transform(_c.value);
          return Transform.scale(scale: 1 - (1 - widget.echelle) * t, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// -------------------------------------------------------------- Apparition

/// Apparition échelonnée : chaque élément d'une grille ou d'une liste arrive
/// en fondu et glisse vers le haut, un peu après le précédent.
class Apparition extends StatelessWidget {
  final int index;
  final Widget child;
  final double distance;
  const Apparition({super.key, required this.index, required this.child, this.distance = 24});

  @override
  Widget build(BuildContext context) {
    final total = duree(context, 380 + math.min(index, 14) * 45);
    if (total == Duration.zero) return child;
    final debut = 1 - 380 / (380 + math.min(index, 14) * 45);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (_, v, c) {
        final t = Curves.easeOutCubic.transform(((v - debut) / (1 - debut)).clamp(0, 1));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, distance * (1 - t)), child: c),
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------- Pulsation

/// Halo qui respire autour d'un élément (table en attente de paiement).
class Pulsation extends StatefulWidget {
  final Widget child;
  final Color couleur;
  final bool active;
  final BorderRadius rayon;
  const Pulsation({super.key, required this.child, required this.couleur, this.active = true, required this.rayon});

  @override
  State<Pulsation> createState() => _PulsationState();
}

class _PulsationState extends State<Pulsation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maj();
  }

  @override
  void didUpdateWidget(Pulsation old) {
    super.didUpdateWidget(old);
    _maj();
  }

  void _maj() {
    if (widget.active && animationsActives(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final t = Curves.easeOut.transform(_c.value);
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.rayon,
          boxShadow: widget.active
              ? [
                  BoxShadow(
                    color: widget.couleur.withValues(alpha: 0.55 * (1 - t)),
                    blurRadius: 4 + 18 * t,
                    spreadRadius: 10 * t,
                  ),
                ]
              : const [],
        ),
        child: child,
      );
    },
    child: widget.child,
  );
}

/// Petit point lumineux qui pulse (indicateur « En ligne »).
class PointPulsant extends StatefulWidget {
  final Color couleur;
  final double taille;
  const PointPulsant({super.key, required this.couleur, this.taille = 9});
  @override
  State<PointPulsant> createState() => _PointPulsantState();
}

class _PointPulsantState extends State<PointPulsant> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (animationsActives(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.taille * 2.2,
    height: widget.taille * 2.2,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: _Onde(widget.couleur, _c.value, widget.taille / 2)),
    ),
  );
}

class _Onde extends CustomPainter {
  final Color c;
  final double t;
  final double r;
  _Onde(this.c, this.t, this.r);
  @override
  void paint(Canvas canvas, Size size) {
    final o = size.center(Offset.zero);
    canvas.drawCircle(o, r + r * 1.2 * t, Paint()..color = c.withValues(alpha: 0.45 * (1 - t)));
    canvas.drawCircle(o, r, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_Onde old) => old.t != t || old.c != c;
}

// ------------------------------------------------------------------ Secousse

/// Secoue son contenu (code PIN incorrect). Appeler [SecousseState.secouer].
class Secousse extends StatefulWidget {
  final Widget child;
  const Secousse({super.key, required this.child});
  @override
  State<Secousse> createState() => SecousseState();
}

class SecousseState extends State<Secousse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

  void secouer() {
    HapticFeedback.heavyImpact();
    if (animationsActives(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final dx = math.sin(_c.value * math.pi * 6) * 14 * (1 - _c.value);
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
    child: widget.child,
  );
}

// ------------------------------------------------------------- Pastille qté

/// Bulle de quantité qui apparaît en grossissant et rebondit à chaque ajout.
class BulleQuantite extends StatelessWidget {
  final int quantite;
  const BulleQuantite(this.quantite, {super.key});

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: quantite > 0 ? 1 : 0,
    duration: duree(context, 260),
    curve: Curves.easeOutBack,
    child: TweenAnimationBuilder<double>(
      key: ValueKey(quantite),
      tween: Tween(begin: 1.35, end: 1),
      duration: duree(context, 320),
      curve: Curves.elasticOut,
      builder: (_, s, c) => Transform.scale(scale: s, child: c),
      child: Container(
        constraints: const BoxConstraints(minWidth: 28),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: identite.nuit,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: identite.accent, width: 2),
        ),
        child: Text(
          '$quantite',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    ),
  );
}

/// Chiffre qui défile verticalement quand il change (quantités du panier).
class ChiffreDefilant extends StatelessWidget {
  final int valeur;
  final TextStyle? style;
  const ChiffreDefilant(this.valeur, {super.key, this.style});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: duree(context, 240),
    transitionBuilder: (child, a) {
      final entrant = child.key == ValueKey(valeur);
      return ClipRect(
        child: SlideTransition(
          position: Tween(begin: Offset(0, entrant ? 0.8 : -0.8), end: Offset.zero).animate(a),
          child: FadeTransition(opacity: a, child: child),
        ),
      );
    },
    child: Text('$valeur', key: ValueKey(valeur), style: style, textAlign: TextAlign.center),
  );
}

// ---------------------------------------------------------- Célébrations

/// Affiche au-dessus de l'écran une coche dessinée à la main, entourée
/// d'une gerbe d'étincelles aux couleurs de l'identité, puis disparaît.
void celebrer(BuildContext context, String message, {IconData? icone, Color? couleur}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  HapticFeedback.mediumImpact();
  late OverlayEntry entree;
  entree = OverlayEntry(
    builder: (_) =>
        _Celebration(message: message, couleur: couleur ?? identite.tableLibre, quandFini: () => entree.remove()),
  );
  overlay.insert(entree);
}

class _Celebration extends StatefulWidget {
  final String message;
  final Color couleur;
  final VoidCallback quandFini;
  const _Celebration({required this.message, required this.couleur, required this.quandFini});
  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final d = duree(context, 1500);
      if (d == Duration.zero) {
        Future.delayed(const Duration(milliseconds: 900), widget.quandFini);
        _c.value = 0.5;
        return;
      }
      _c.duration = d;
      _c.forward().then((_) => widget.quandFini());
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final v = _c.value;
        final entree = Curves.easeOutBack.transform((v / 0.3).clamp(0, 1));
        final sortie = ((v - 0.8) / 0.2).clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - sortie,
          child: Center(
            child: Transform.scale(
              scale: 0.6 + 0.4 * entree,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 170, height: 170, child: CustomPaint(painter: _Coche(v, widget.couleur))),
                  const SizedBox(height: 8),
                  Material(
                    color: identite.nuit,
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontFamily: identite.policeTitres,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Coche extends CustomPainter {
  final double t;
  final Color couleur;
  _Coche(this.t, this.couleur);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.3;
    // Étincelles.
    final gerbe = ((t - 0.15) / 0.6).clamp(0.0, 1.0);
    if (gerbe > 0 && gerbe < 1) {
      final couleurs = [identite.accent, identite.principale, couleur, identite.tableAddition];
      for (var i = 0; i < 14; i++) {
        final a = i * 2 * math.pi / 14 + 0.2;
        final d = r * (1.15 + 0.75 * Curves.easeOut.transform(gerbe));
        final o = c + Offset(math.cos(a), math.sin(a)) * d;
        final s = 6 * (1 - gerbe);
        final p = Paint()..color = couleurs[i % couleurs.length].withValues(alpha: 1 - gerbe);
        if (i.isEven) {
          canvas.drawCircle(o, s, p);
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(o.dx, o.dy - s * 1.3)
              ..lineTo(o.dx + s, o.dy)
              ..lineTo(o.dx, o.dy + s * 1.3)
              ..lineTo(o.dx - s, o.dy)
              ..close(),
            p,
          );
        }
      }
    }
    // Disque.
    final disque = Curves.easeOutBack.transform((t / 0.3).clamp(0, 1));
    canvas.drawCircle(c, r * disque, Paint()..color = couleur);
    canvas.drawCircle(
      c,
      r * disque * 1.08,
      Paint()
        ..color = identite.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Coche dessinée progressivement.
    final trace = ((t - 0.2) / 0.3).clamp(0.0, 1.0);
    if (trace > 0) {
      final chemin = Path()
        ..moveTo(c.dx - r * 0.45, c.dy + r * 0.02)
        ..lineTo(c.dx - r * 0.12, c.dy + r * 0.35)
        ..lineTo(c.dx + r * 0.5, c.dy - r * 0.32);
      final m = chemin.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * trace),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_Coche old) => old.t != t;
}

/// Tampon « PAYÉE » qui s'abat sur l'écran après un encaissement.
void tamponner(BuildContext context, String texte, {Color? couleur}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  HapticFeedback.heavyImpact();
  late OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => Material(
      type: MaterialType.transparency,
      child: _Tampon(texte: texte, couleur: couleur ?? identite.tableLibre, fin: () => e.remove()),
    ),
  );
  overlay.insert(e);
}

class _Tampon extends StatefulWidget {
  final String texte;
  final Color couleur;
  final VoidCallback fin;
  const _Tampon({required this.texte, required this.couleur, required this.fin});
  @override
  State<_Tampon> createState() => _TamponState();
}

class _TamponState extends State<_Tampon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final d = duree(context, 1400);
      if (d == Duration.zero) {
        _c.value = 0.5;
        Future.delayed(const Duration(milliseconds: 900), widget.fin);
        return;
      }
      _c.duration = d;
      _c.forward().then((_) => widget.fin());
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final v = _c.value;
        final chute = Curves.easeInCubic.transform((v / 0.22).clamp(0, 1));
        final sortie = ((v - 0.8) / 0.2).clamp(0.0, 1.0);
        return Opacity(
          opacity: (chute * 1.2).clamp(0, 1) * (1 - sortie),
          child: Center(
            child: Transform.rotate(
              angle: -0.22,
              child: Transform.scale(
                scale: 2.6 - 1.6 * chute,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: widget.couleur, width: 6),
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  child: Text(
                    widget.texte,
                    style: TextStyle(
                      fontFamily: identite.policeTitres,
                      fontWeight: FontWeight.w800,
                      fontSize: 56,
                      letterSpacing: 4,
                      color: widget.couleur,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
