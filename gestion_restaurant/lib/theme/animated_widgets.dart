import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import 'app_theme.dart';
import 'identite.dart';

/// ============================================================================
///  WIDGETS ANIMÉS RÉUTILISABLES
/// ============================================================================
///
/// Règles de performance (service en plein rush, tablettes d'entrée de gamme) :
/// - animations implicites ou un seul `AnimationController` par widget ;
/// - `RepaintBoundary` autour de tout ce qui boucle (halo, shimmer, point) ;
/// - aucune reconstruction de l'arbre parent pendant une animation : les
///   `AnimatedBuilder` ne reconstruisent que la partie qui bouge ;
/// - réglage « réduire les animations » respecté partout via [duree].

/// Durée ajustée à [IdentiteVisuelle.vitesseAnimations] et au réglage
/// d'accessibilité de l'appareil (zéro = pas d'animation).
Duration duree(BuildContext context, int millisecondes) {
  if (!animationsActives(context)) return Duration.zero;
  return Duration(milliseconds: (millisecondes / identite.vitesseAnimations).round());
}

bool animationsActives(BuildContext context) =>
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) && identite.vitesseAnimations > 0;

// ============================================================ BouncyTapWrapper

/// Effet d'enfoncement physique : 0,95 à l'appui, retour élastique
/// (`Curves.easeOutBack`) au relâchement, vibration légère.
///
/// La réaction visuelle démarre dès `onTapDown` (avant que le geste soit
/// confirmé) : la serveuse « sent » le bouton immédiatement.
class BouncyTapWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptique;

  const BouncyTapWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.haptique = true,
  });

  @override
  State<BouncyTapWrapper> createState() => _BouncyTapWrapperState();
}

class _BouncyTapWrapperState extends State<BouncyTapWrapper> {
  bool _presse = false;

  bool get _actif => widget.onTap != null || widget.onLongPress != null;

  void _poser(bool v) {
    if (_presse != v && mounted) setState(() => _presse = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _actif ? (_) => _poser(true) : null,
      onTapUp: _actif ? (_) => _poser(false) : null,
      onTapCancel: _actif ? () => _poser(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptique) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _poser(false);
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _presse ? widget.scale : 1,
        duration: duree(context, _presse ? 90 : 420),
        curve: _presse ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// =========================================================== SmoothCounterText

/// Nombre qui « compte » jusqu'à sa nouvelle valeur (12 500 F → 13 200 F),
/// en chiffres tabulaires pour que la largeur ne bouge pas.
class SmoothCounterText extends StatefulWidget {
  final int valeur;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// Mise en forme du nombre (par défaut : montant FCFA).
  final String Function(int) format;
  final int millisecondes;

  const SmoothCounterText(
    this.valeur, {
    super.key,
    this.style,
    this.textAlign,
    this.format = fcfa,
    this.millisecondes = 600,
  });

  /// Compteur simple (nombre de tables, de factures…).
  const SmoothCounterText.nombre(this.valeur, {super.key, this.style, this.textAlign, this.millisecondes = 450})
    : format = _entier;

  static String _entier(int v) => '$v';

  @override
  State<SmoothCounterText> createState() => _SmoothCounterTextState();
}

class _SmoothCounterTextState extends State<SmoothCounterText> {
  late double _depart = widget.valeur.toDouble();

  @override
  void didUpdateWidget(SmoothCounterText old) {
    super.didUpdateWidget(old);
    if (old.valeur != widget.valeur) _depart = old.valeur.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTypo.chiffres(DefaultTextStyle.of(context).style.merge(widget.style));
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.valeur),
      tween: Tween(begin: _depart, end: widget.valeur.toDouble()),
      duration: duree(context, widget.millisecondes),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(widget.format(v.round()), style: style, textAlign: widget.textAlign),
    );
  }
}

// ============================================================ StaggeredEntrance

/// Apparition en cascade : fondu + glissement de 15 px vers le haut sur
/// 250 ms (`Curves.easeOutCubic`), chaque élément un peu après le précédent.
/// Le décalage est plafonné : la 40e table n'attend pas 2 secondes.
class StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;
  final double distance;
  final int dureeMs;
  final int decalageMs;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.distance = 15,
    this.dureeMs = 250,
    this.decalageMs = 35,
  });

  @override
  Widget build(BuildContext context) {
    final retard = math.min(index, 12) * decalageMs;
    final total = duree(context, dureeMs + retard);
    if (total == Duration.zero) return child;
    // Interval : l'élément reste invisible pendant son retard, puis s'anime.
    final courbe = Interval(retard / (dureeMs + retard), 1, curve: Curves.easeOutCubic);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (_, v, c) {
        final t = courbe.transform(v);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, distance * (1 - t)), child: c),
        );
      },
      child: child,
    );
  }
}

// ================================================================== PulseGlow

/// Halo lumineux qui respire autour d'un élément.
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color couleur;
  final bool active;
  final BorderRadius rayon;
  final int periodeMs;

  const PulseGlow({
    super.key,
    required this.child,
    required this.couleur,
    required this.rayon,
    this.active = true,
    this.periodeMs = 1600,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.periodeMs),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _majBoucle();
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    _majBoucle();
  }

  void _majBoucle() {
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
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return CustomPaint(
      // Le halo est peint derrière, dans sa propre couche : l'enfant n'est
      // jamais reconstruit à chaque image.
      painter: _HaloPainter(_c, widget.couleur, widget.rayon),
      child: widget.child,
    );
  }
}

class _HaloPainter extends CustomPainter {
  final Animation<double> t;
  final Color couleur;
  final BorderRadius rayon;
  _HaloPainter(this.t, this.couleur, this.rayon) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeOut.transform(t.value);
    final ecart = 2 + 10 * v;
    final rect = (Offset.zero & size).inflate(ecart);
    final rr = rayon.resolve(TextDirection.ltr).toRRect(rect);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = couleur.withValues(alpha: 0.55 * (1 - v))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 8 * v),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.couleur != couleur || old.rayon != rayon;
}

// ============================================================== PulseAlertBadge

/// Alerte qui attire l'œil : halo respirant autour de [child] et, si
/// [label] est donné, une pastille qui bat doucement dans le coin.
/// Utilisé pour les tables en attente d'addition (salle et caisse).
class PulseAlertBadge extends StatelessWidget {
  final Widget child;
  final bool active;
  final Color couleur;
  final BorderRadius rayon;
  final String? label;
  final IconData? icone;

  const PulseAlertBadge({
    super.key,
    required this.child,
    required this.active,
    required this.couleur,
    required this.rayon,
    this.label,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PulseGlow(active: active, couleur: couleur, rayon: rayon, child: child),
          if (label != null || icone != null)
            Positioned(
              top: -9,
              right: -6,
              child: AnimatedScale(
                scale: active ? 1 : 0,
                duration: duree(context, 320),
                curve: Curves.easeOutBack,
                child: _BadgeBattant(couleur: couleur, label: label, icone: icone, actif: active),
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeBattant extends StatefulWidget {
  final Color couleur;
  final String? label;
  final IconData? icone;
  final bool actif;
  const _BadgeBattant({required this.couleur, this.label, this.icone, required this.actif});
  @override
  State<_BadgeBattant> createState() => _BadgeBattantState();
}

class _BadgeBattantState extends State<_BadgeBattant> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.actif && animationsActives(context)) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didUpdateWidget(_BadgeBattant old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contenu = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppOmbres.lueur(widget.couleur),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icone != null) Icon(widget.icone, size: 13, color: widget.couleur),
          if (widget.icone != null && widget.label != null) const SizedBox(width: 3),
          if (widget.label != null)
            Text(widget.label!, style: AppTypo.etiquette(widget.couleur, taille: 11, poids: FontWeight.w800)),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, c) {
        // Double battement doux, puis repos.
        final v = _c.value;
        final b = v < 0.15
            ? math.sin(v / 0.15 * math.pi)
            : (v < 0.3 ? 0.6 * math.sin((v - 0.15) / 0.15 * math.pi) : 0.0);
        return Transform.scale(scale: 1 + 0.08 * b, child: c);
      },
      child: contenu,
    );
  }
}

// ==================================================================== LiveDot

/// Point lumineux avec onde qui s'élargit (état « en direct »).
class LiveDot extends StatefulWidget {
  final Color couleur;
  final double taille;
  final bool anime;
  const LiveDot({super.key, required this.couleur, this.taille = 8, this.anime = true});
  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maj();
  }

  @override
  void didUpdateWidget(LiveDot old) {
    super.didUpdateWidget(old);
    _maj();
  }

  void _maj() {
    if (widget.anime && animationsActives(context)) {
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
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: widget.taille * 2.4,
      child: CustomPaint(painter: _OndePainter(_c, widget.couleur, widget.taille / 2)),
    ),
  );
}

class _OndePainter extends CustomPainter {
  final Animation<double> t;
  final Color c;
  final double r;
  _OndePainter(this.t, this.c, this.r) : super(repaint: t);
  @override
  void paint(Canvas canvas, Size size) {
    final o = size.center(Offset.zero);
    final v = t.value;
    canvas.drawCircle(o, r + r * 1.3 * v, Paint()..color = c.withValues(alpha: 0.5 * (1 - v)));
    canvas.drawCircle(o, r, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_OndePainter old) => old.c != c;
}

// ============================================================ OfflineStatusPill

/// Badge réseau animé. Trois états, avec icône + texte (jamais la couleur
/// seule) et un fondu-glissé entre eux :
/// - « En ligne » (émeraude) ;
/// - « Synchronisation – N » : connecté, envois en cours ;
/// - « Hors ligne – N en attente » (ambre) : tout est gardé sur l'appareil.
class OfflineStatusPill extends StatelessWidget {
  final bool enLigne;
  final int enAttente;
  final bool compact;

  const OfflineStatusPill({super.key, required this.enLigne, required this.enAttente, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (String cle, Color couleur, IconData icone, String texte) = !enLigne
        ? (
            'off',
            p.occupee,
            Icons.cloud_off_rounded,
            enAttente > 0 ? 'Hors ligne – $enAttente en attente' : 'Hors ligne',
          )
        : (enAttente > 0
              ? ('sync', p.addition, Icons.sync_rounded, 'Synchronisation – $enAttente')
              : ('on', p.libre, Icons.cloud_done_rounded, 'En ligne'));
    return Semantics(
      liveRegion: true,
      label: texte,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: duree(context, 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(6, 4, compact ? 8 : 12, 4),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: p.sombre ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: couleur.withValues(alpha: 0.55)),
        ),
        child: AnimatedSize(
          duration: duree(context, 280),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: duree(context, 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: Row(
              key: ValueKey('$cle-$enAttente'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cle == 'on')
                  LiveDot(couleur: couleur)
                else
                  _IconeTournante(icone: icone, couleur: couleur, tourne: cle == 'sync'),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  Text(
                    texte,
                    style: AppTypo.chiffres(AppTypo.etiquette(p.sombre ? Colors.white : p.texte, taille: 13)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconeTournante extends StatefulWidget {
  final IconData icone;
  final Color couleur;
  final bool tourne;
  const _IconeTournante({required this.icone, required this.couleur, required this.tourne});
  @override
  State<_IconeTournante> createState() => _IconeTournanteState();
}

class _IconeTournanteState extends State<_IconeTournante> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.tourne && animationsActives(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(2),
    child: RotationTransition(
      turns: _c,
      child: Icon(widget.icone, size: 16, color: widget.couleur),
    ),
  );
}

// ============================================================= ShimmerLoading

/// Reflet qui balaie des formes de chargement (au lieu d'une roue qui tourne).
/// Un seul contrôleur pour tout le bloc ; les formes sont des [ShimmerBlock].
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});
  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

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
  Widget build(BuildContext context) {
    final p = context.pal;
    final base = p.sombre ? Colors.white.withValues(alpha: 0.06) : p.texte.withValues(alpha: 0.06);
    final reflet = p.sombre ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.9);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) {
            final x = -1.5 + 3 * _c.value;
            return LinearGradient(
              begin: Alignment(x - 0.6, -0.3),
              end: Alignment(x + 0.6, 0.3),
              colors: [base, reflet, base],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(r);
          },
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Forme pleine à placer dans un [ShimmerLoading].
class ShimmerBlock extends StatelessWidget {
  final double? largeur;
  final double? hauteur;
  final double rayon;
  const ShimmerBlock({super.key, this.largeur, this.hauteur, this.rayon = 12});
  @override
  Widget build(BuildContext context) => Container(
    width: largeur,
    height: hauteur,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(rayon)),
  );
}

// ================================================================== GlassPanel

/// Panneau « verre dépoli » pour les barres flottantes et les feuilles
/// modales. Le flou est coûteux : à réserver aux éléments fixes et peu
/// nombreux (une barre par écran), jamais dans une liste.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius rayon;
  final EdgeInsetsGeometry padding;
  final double flou;

  const GlassPanel({
    super.key,
    required this.child,
    this.rayon = const BorderRadius.all(Radius.circular(28)),
    this.padding = const EdgeInsets.all(10),
    this.flou = 18,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: rayon, boxShadow: AppOmbres.douce(p, force: 1.2)),
      child: ClipRRect(
        borderRadius: rayon,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: flou, sigmaY: flou),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: rayon,
              color: (p.sombre ? p.surfaceElevee : p.surface).withValues(alpha: p.sombre ? 0.72 : 0.78),
              border: Border.all(color: p.sombre ? Colors.white.withValues(alpha: 0.10) : p.bordure),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ======================================================== GradientActionButton

/// Bouton d'action principal : dégradé orange du logo, lueur, rebond.
/// Hauteur minimale 56 dp (usage tablette en service).
class GradientActionButton extends StatelessWidget {
  final String label;
  final IconData? icone;
  final VoidCallback? onPressed;
  final Color? couleur;
  final double hauteur;
  final Widget? trailing;

  const GradientActionButton({
    super.key,
    required this.label,
    this.icone,
    this.onPressed,
    this.couleur,
    this.hauteur = 56,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final actif = onPressed != null;
    final c = couleur ?? p.principale;
    return Semantics(
      button: true,
      enabled: actif,
      label: label,
      excludeSemantics: true,
      child: BouncyTapWrapper(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: duree(context, 250),
          constraints: BoxConstraints(minHeight: hauteur),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: actif ? degradePrincipal(c) : null,
            color: actif ? null : p.texte.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(identite.arrondi * 0.8),
            boxShadow: actif ? AppOmbres.lueur(c) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icone != null) ...[
                Icon(icone, color: actif ? Colors.white : p.texteDiscret, size: 22),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypo.chiffres(
                    AppTypo.etiquette(actif ? Colors.white : p.texteDiscret, taille: 17, poids: FontWeight.w700),
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================== QuantityBadge

/// Pastille de quantité : apparaît en grossissant, puis « pop » à chaque
/// changement (AnimatedSwitcher + échelle élastique).
class QuantityBadge extends StatelessWidget {
  final int quantite;
  final Color? couleur;
  const QuantityBadge(this.quantite, {super.key, this.couleur});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AnimatedScale(
      scale: quantite > 0 ? 1 : 0,
      duration: duree(context, 260),
      curve: Curves.easeOutBack,
      child: AnimatedSwitcher(
        duration: duree(context, 300),
        transitionBuilder: (child, a) => ScaleTransition(
          scale: Tween(begin: 1.6, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.elasticOut)),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: Container(
          key: ValueKey(quantite),
          constraints: const BoxConstraints(minWidth: 30),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: couleur ?? p.principale,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: p.sombre ? p.fond : Colors.white, width: 2.5),
            boxShadow: AppOmbres.lueur(couleur ?? p.principale, force: 0.8),
          ),
          child: Text(
            '$quantite',
            style: AppTypo.chiffres(const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

/// Chiffre qui défile verticalement quand il change (quantités du panier).
class RollingNumber extends StatelessWidget {
  final int valeur;
  final TextStyle? style;
  const RollingNumber(this.valeur, {super.key, this.style});

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
    child: Text(
      '$valeur',
      key: ValueKey(valeur),
      style: AppTypo.chiffres(style ?? const TextStyle()),
      textAlign: TextAlign.center,
    ),
  );
}

// =============================================================== ShakeWrapper

/// Secoue son contenu (code PIN incorrect). Appeler
/// `GlobalKey<ShakeWrapperState>().currentState?.secouer()`.
class ShakeWrapper extends StatefulWidget {
  final Widget child;
  const ShakeWrapper({super.key, required this.child});
  @override
  State<ShakeWrapper> createState() => ShakeWrapperState();
}

class ShakeWrapperState extends State<ShakeWrapper> with SingleTickerProviderStateMixin {
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

// ============================================================ Célébrations

/// Coche dessinée à la main + gerbe d'étincelles aux couleurs du logo,
/// affichée par-dessus l'écran puis effacée (« Envoyé en caisse »).
void showSuccessBurst(BuildContext context, String message, {Color? couleur}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  HapticFeedback.mediumImpact();
  late OverlayEntry entree;
  entree = OverlayEntry(
    builder: (_) => Material(
      type: MaterialType.transparency,
      child: _Celebration(message: message, couleur: couleur ?? identite.tableLibre, fin: () => entree.remove()),
    ),
  );
  overlay.insert(entree);
}

class _Celebration extends StatefulWidget {
  final String message;
  final Color couleur;
  final VoidCallback fin;
  const _Celebration({required this.message, required this.couleur, required this.fin});
  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
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
    child: RepaintBoundary(
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
                    SizedBox.square(dimension: 170, child: CustomPaint(painter: _Coche(v, widget.couleur))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      decoration: BoxDecoration(
                        color: identite.secondaire,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: identite.accent.withValues(alpha: 0.5)),
                      ),
                      child: Text(widget.message, style: AppTypo.titre(Colors.white, taille: 19)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
    final gerbe = ((t - 0.15) / 0.6).clamp(0.0, 1.0);
    if (gerbe > 0 && gerbe < 1) {
      final couleurs = [identite.principale, identite.accent, couleur, identite.tableAddition];
      for (var i = 0; i < 14; i++) {
        final a = i * 2 * math.pi / 14 + 0.2;
        final o = c + Offset(math.cos(a), math.sin(a)) * r * (1.15 + 0.75 * Curves.easeOut.transform(gerbe));
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
void showStamp(BuildContext context, String texte, {Color? couleur}) {
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
    child: RepaintBoundary(
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
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    child: Text(
                      widget.texte,
                      style: AppTypo.titre(widget.couleur, taille: 54).copyWith(letterSpacing: 4),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
