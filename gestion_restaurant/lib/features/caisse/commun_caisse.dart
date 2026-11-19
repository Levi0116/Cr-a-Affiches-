import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/impression/impression.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../widgets/commun.dart';
import 'comptage.dart';

/// Imprime un ticket ; sur tablette (sans imprimante), prévient.
Future<void> imprimer(BuildContext context, String html) async {
  final ok = await imprimerHtml(html);
  if (!ok && context.mounted) {
    afficherMessage(context, 'Impression disponible sur l’ordinateur de la caisse');
  }
}

/// Ouverture de caisse : comptage du fond par billets et pièces.
Future<void> ouvrirCaisse(BuildContext context, WidgetRef ref) async {
  final fond = await demanderComptage(
    context,
    titre: 'Ouverture de caisse',
    sousTitre: 'Comptez le fond de caisse',
    libelleBouton: 'Ouvrir la caisse',
  );
  if (fond == null || !context.mounted) return;
  await essayer(
    context,
    () => ref.read(caisseServiceProvider).ouvrirCaisse(ref.read(acteurProvider)!, fond),
    succes: 'Caisse ouverte',
  );
}

/// « depuis 42 min », « depuis 1 h 05 ».
String depuis(DateTime debut, DateTime maintenant) {
  final d = maintenant.difference(debut);
  if (d.inMinutes < 1) return 'à l’instant';
  if (d.inMinutes < 60) return 'depuis ${d.inMinutes} min';
  return 'depuis ${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')}';
}

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
