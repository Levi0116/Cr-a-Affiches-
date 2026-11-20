import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'identite.dart';

/// Motif « Kita » : bandes tissées inspirées des pagnes de Côte d'Ivoire
/// (bandes de damiers, dents de scie, calebasses), dessinées à la volée.
/// Création originale : aucune image à charger.
class MotifPainter extends CustomPainter {
  final Color couleur;
  final double opacite;

  /// Décalage (0..1) pour un défilement lent animé.
  final double decalage;
  const MotifPainter({required this.couleur, this.opacite = 0.12, this.decalage = 0});

  @override
  void paint(Canvas canvas, Size size) {
    const bande = 72.0; // hauteur d'un motif complet
    final plein = Paint()..color = couleur.withValues(alpha: opacite);
    final leger = Paint()..color = couleur.withValues(alpha: opacite * 0.55);
    final trait = Paint()
      ..color = couleur.withValues(alpha: opacite)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final dx = -decalage * 48;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    var rangee = 0;
    for (double y = -bande; y < size.height + bande; y += bande, rangee++) {
      // 1. Bande de damier tissé (petits carrés alternés).
      const c = 6.0;
      for (double x = dx - 48; x < size.width + 48; x += c * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, c, c), plein);
        canvas.drawRect(Rect.fromLTWH(x + c, y + c, c, c), plein);
      }
      // 2. Dents de scie.
      final dents = Path();
      const d = 12.0;
      final yd = y + 22;
      for (double x = dx - 48; x < size.width + 48; x += d) {
        dents
          ..moveTo(x, yd + d * 0.7)
          ..lineTo(x + d / 2, yd)
          ..lineTo(x + d, yd + d * 0.7);
      }
      canvas.drawPath(dents, trait);
      // 3. Calebasses (cercles concentriques) une rangée sur deux, losanges sinon.
      final yc = y + 52;
      for (double x = dx - 48 + (rangee.isOdd ? 24 : 0); x < size.width + 48; x += 48) {
        final o = Offset(x, yc);
        if (rangee.isEven) {
          canvas.drawCircle(o, 8, trait);
          canvas.drawCircle(o, 3, plein);
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(o.dx, o.dy - 7)
              ..lineTo(o.dx + 7, o.dy)
              ..lineTo(o.dx, o.dy + 7)
              ..lineTo(o.dx - 7, o.dy)
              ..close(),
            leger,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MotifPainter old) => old.couleur != couleur || old.opacite != opacite || old.decalage != decalage;
}

/// Liseré tissé (bande décorative fine) : sous les en-têtes, au bas des cartes.
class BandeKita extends StatelessWidget {
  final double hauteur;
  final List<Color>? couleurs;
  const BandeKita({super.key, this.hauteur = 8, this.couleurs});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: hauteur,
    width: double.infinity,
    child: CustomPaint(painter: _BandeKitaPainter(couleurs ?? [identite.principale, identite.or, identite.secondaire, identite.accent])),
  );
}

class _BandeKitaPainter extends CustomPainter {
  final List<Color> couleurs;
  _BandeKitaPainter(this.couleurs);
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    var i = 0;
    for (double x = 0; x < size.width; x += h * 1.5, i++) {
      canvas.drawRect(Rect.fromLTWH(x, 0, h * 1.5, h), Paint()..color = couleurs[i % couleurs.length]);
      // Petit triangle tissé alterné.
      final t = Path()
        ..moveTo(x, i.isEven ? 0 : h)
        ..lineTo(x + h * 0.75, h / 2)
        ..lineTo(x, i.isEven ? h : 0)
        ..close();
      canvas.drawPath(t, Paint()..color = Colors.black.withValues(alpha: 0.12));
    }
  }

  @override
  bool shouldRepaint(_BandeKitaPainter old) => false;
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

/// Fond de barre d'application : nuit de forêt, motif doré discret et liseré tissé.
class BandeauMotif extends StatelessWidget {
  const BandeauMotif({super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [identite.nuit, identite.secondaire],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (identite.motif) CustomPaint(painter: MotifPainter(couleur: identite.or, opacite: 0.10)),
        const Align(alignment: Alignment.bottomCenter, child: BandeKita(hauteur: 5)),
      ],
    ),
  );
}

/// Nom du restaurant et slogan, en police de marque.
class TitreMarque extends StatelessWidget {
  final Color couleur;
  final double taille;
  final bool slogan;
  final CrossAxisAlignment alignement;
  const TitreMarque({
    super.key,
    this.couleur = Colors.white,
    this.taille = 30,
    this.slogan = true,
    this.alignement = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: alignement,
    children: [
      Text(
        identite.nomRestaurant,
        textAlign: alignement == CrossAxisAlignment.center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontFamily: identite.policeMarque,
          fontWeight: FontWeight.w700,
          fontSize: taille,
          color: couleur,
          height: 1.1,
          letterSpacing: -0.4,
        ),
      ),
      if (slogan && identite.slogan.isNotEmpty) ...[
        SizedBox(height: taille * 0.22),
        Text(
          identite.slogan,
          textAlign: alignement == CrossAxisAlignment.center ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontFamily: identite.policeMarque,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            fontSize: taille * 0.5,
            color: identite.or,
          ),
        ),
      ],
    ],
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
      return Container(
        width: taille,
        height: taille,
        padding: EdgeInsets.all(taille * 0.035),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [identite.or, identite.accent, identite.principale, identite.or]),
          boxShadow: [BoxShadow(color: identite.principale.withValues(alpha: 0.35), blurRadius: taille * 0.25)],
        ),
        child: ClipOval(child: Image.asset(identite.logoAsset!, fit: BoxFit.cover)),
      );
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
