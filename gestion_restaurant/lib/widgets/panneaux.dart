import 'package:material_ui/material_ui.dart';

import '../theme/animated_widgets.dart';
import '../theme/app_theme.dart';
import '../theme/identite.dart';

/// Panneau blanc élevé, bordé, avec ombres douces.
class PanneauCaisse extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? couleur;
  const PanneauCaisse({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.couleur});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: couleur ?? p.surface,
        borderRadius: BorderRadius.circular(identite.arrondi * 1.1),
        border: Border.all(color: p.bordure),
        boxShadow: AppOmbres.douce(p),
      ),
      child: child,
    );
  }
}

/// Titre de section avec icône.
class TitreSection extends StatelessWidget {
  final IconData icone;
  final String titre;
  final Widget? trailing;
  const TitreSection({super.key, required this.icone, required this.titre, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: p.principale.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 19, color: p.principale),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(titre, style: AppTypo.titre(p.texte, taille: 18, poids: FontWeight.w700)),
        ),
        ?trailing,
      ],
    );
  }
}

/// Ligne pointillée de ticket de caisse.
class Pointilles extends StatelessWidget {
  final Color? couleur;
  const Pointilles({super.key, this.couleur});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 14,
    width: double.infinity,
    child: CustomPaint(painter: _PointillesPainter(couleur ?? context.pal.texteDiscret)),
  );
}

class _PointillesPainter extends CustomPainter {
  final Color c;
  _PointillesPainter(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = c
      ..strokeWidth = 1.2;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), p);
    }
  }

  @override
  bool shouldRepaint(_PointillesPainter old) => old.c != c;
}

/// Un onglet du [SelecteurSections].
class ItemSection<T> {
  final T valeur;
  final IconData icone;
  final String nom;
  final int? compte;
  const ItemSection(this.valeur, this.icone, this.nom, [this.compte]);
}

/// Sélecteur de sections : un indicateur en dégradé glisse sous l'onglet
/// actif ; chaque onglet peut porter un compteur.
class SelecteurSections<T> extends StatelessWidget {
  final List<ItemSection<T>> items;
  final T valeur;
  final ValueChanged<T> onChange;
  final double largeurMax;
  const SelecteurSections({
    super.key,
    required this.items,
    required this.valeur,
    required this.onChange,
    this.largeurMax = 760,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final index = items.indexWhere((x) => x.valeur == valeur);
    return LayoutBuilder(
      builder: (context, c) {
        // 2 × 6 de marge intérieure + 2 × 1 de bordure.
        final largeurOnglet = (c.maxWidth.clamp(0, largeurMax) - 14) / items.length;
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: largeurOnglet * items.length + 14,
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
                    for (final it in items)
                      SizedBox(
                        width: largeurOnglet,
                        child: Semantics(
                          container: true,
                          button: true,
                          selected: it.valeur == valeur,
                          label: '${it.nom}${it.compte == null ? '' : ', ${it.compte}'}',
                          excludeSemantics: true,
                          child: BouncyTapWrapper(
                            onTap: () => onChange(it.valeur),
                            child: _Onglet(item: it, actif: it.valeur == valeur),
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
  final ItemSection<Object?> item;
  final bool actif;
  const _Onglet({required this.item, required this.actif});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = actif ? Colors.white : p.texteSecondaire;
    final compte = item.compte;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icone, size: 20, color: c),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: duree(context, 250),
                style: AppTypo.etiquette(c, taille: 15, poids: FontWeight.w700),
                child: Text(item.nom),
              ),
              if (compte != null && compte > 0) ...[
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: duree(context, 250),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: actif ? Colors.white.withValues(alpha: 0.22) : p.principale.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SmoothCounterText.nombre(
                    compte,
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

/// En-tête de page d'administration : titre, description, action principale.
class EnTetePage extends StatelessWidget {
  final String titre;
  final String? description;
  final Widget? action;
  const EnTetePage({super.key, required this.titre, this.description, this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: AppTypo.marque(p.texte, taille: 32)),
                if (description != null)
                  Text(description!, style: AppTypo.etiquette(p.texteSecondaire, taille: 14, poids: FontWeight.w500)),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
