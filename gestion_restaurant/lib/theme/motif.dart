import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'identite.dart';

/// Motif géométrique original (losanges, chevrons et points) inspiré des
/// tissages d'Afrique de l'Ouest, dessiné à la volée : aucune image à charger.
class MotifPainter extends CustomPainter {
  final Color couleur;
  final double opacite;

  /// Décalage horizontal (0..1) pour un défilement lent animé.
  final double decalage;
  const MotifPainter({required this.couleur, this.opacite = 0.12, this.decalage = 0});

  @override
  void paint(Canvas canvas, Size size) {
    const pas = 44.0;
    final trait = Paint()
      ..color = couleur.withValues(alpha: opacite)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final plein = Paint()..color = couleur.withValues(alpha: opacite * 1.2);
    final dx = -decalage * pas * 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    var rangee = 0;
    for (double y = -pas; y < size.height + pas; y += pas, rangee++) {
      final impaire = rangee.isOdd;
      for (double x = dx - pas * 2 + (impaire ? pas / 2 : 0); x < size.width + pas * 2; x += pas) {
        final c = Offset(x, y);
        // Losange.
        final l = Path()
          ..moveTo(c.dx, c.dy - pas * 0.32)
          ..lineTo(c.dx + pas * 0.32, c.dy)
          ..lineTo(c.dx, c.dy + pas * 0.32)
          ..lineTo(c.dx - pas * 0.32, c.dy)
          ..close();
        canvas.drawPath(l, trait);
        // Point central ou petit losange plein une rangée sur deux.
        if (impaire) {
          canvas.drawCircle(c, 2.2, plein);
        } else {
          final p = Path()
            ..moveTo(c.dx, c.dy - 5)
            ..lineTo(c.dx + 5, c.dy)
            ..lineTo(c.dx, c.dy + 5)
            ..lineTo(c.dx - 5, c.dy)
            ..close();
          canvas.drawPath(p, plein);
        }
      }
      // Frise de chevrons entre les rangées.
      final yc = y + pas / 2;
      final chevrons = Path();
      for (double x = dx - pas * 2; x < size.width + pas * 2; x += pas / 2) {
        chevrons
          ..moveTo(x, yc + 3)
          ..lineTo(x + pas / 4, yc - 3)
          ..lineTo(x + pas / 2, yc + 3);
      }
      canvas.drawPath(chevrons, trait..strokeWidth = 1);
      trait.strokeWidth = 1.6;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MotifPainter old) => old.couleur != couleur || old.opacite != opacite || old.decalage != decalage;
}

/// Fond décoré du motif, qui défile très lentement.
class FondMotif extends StatefulWidget {
  final Widget child;
  final Color? couleurFond;
  final Color? couleurMotif;
  final double opacite;
  final bool anime;
  const FondMotif({
    super.key,
    required this.child,
    this.couleurFond,
    this.couleurMotif,
    this.opacite = 0.10,
    this.anime = true,
  });

  @override
  State<FondMotif> createState() => _FondMotifState();
}

class _FondMotifState extends State<FondMotif> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calme = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.anime && identite.vitesseAnimations > 0 && !calme) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!identite.motif) {
      return ColoredBox(color: widget.couleurFond ?? Colors.transparent, child: widget.child);
    }
    return ColoredBox(
      color: widget.couleurFond ?? Colors.transparent,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(
                  painter: MotifPainter(
                    couleur: widget.couleurMotif ?? identite.accent,
                    opacite: widget.opacite,
                    decalage: _c.value,
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Fond de barre d'application : nuit + motif doré discret + liseré.
class BandeauMotif extends StatelessWidget {
  const BandeauMotif({super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: identite.nuit,
      border: Border(bottom: BorderSide(color: identite.accent, width: 3)),
    ),
    child: identite.motif
        ? CustomPaint(painter: MotifPainter(couleur: identite.accent, opacite: 0.09))
        : const SizedBox.expand(),
  );
}

/// Logo du restaurant, ou monogramme provisoire dans un médaillon tissé.
class LogoResto extends StatelessWidget {
  final String nom;
  final double taille;
  const LogoResto({super.key, required this.nom, this.taille = 96});

  String get _initiales {
    const mots = {'le', 'la', 'les', 'de', 'du', 'des', 'maquis', 'restaurant', 'chez', "l'", 'au', 'aux'};
    final m = nom.split(RegExp(r"[\s']+")).where((w) => w.isNotEmpty && !mots.contains(w.toLowerCase())).toList();
    if (m.isEmpty) return nom.isEmpty ? '?' : nom[0].toUpperCase();
    return m.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    if (identite.logoAsset != null) {
      return Image.asset(identite.logoAsset!, width: taille, height: taille);
    }
    return SizedBox(
      width: taille,
      height: taille,
      child: CustomPaint(
        painter: _Medaillon(),
        child: Center(
          child: Text(
            _initiales,
            style: TextStyle(
              fontFamily: identite.policeTitres,
              fontWeight: FontWeight.w800,
              fontSize: taille * 0.34,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Medaillon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = identite.principale);
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..color = identite.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04,
    );
    // Couronne de petits losanges.
    final p = Paint()..color = identite.accent;
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      final o = c + Offset(math.cos(a), math.sin(a)) * r * 0.93;
      final s = r * 0.045;
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - s)
          ..lineTo(o.dx + s, o.dy)
          ..lineTo(o.dx, o.dy + s)
          ..lineTo(o.dx - s, o.dy)
          ..close(),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_Medaillon old) => false;
}
