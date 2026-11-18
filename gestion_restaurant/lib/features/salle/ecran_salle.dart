import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../widgets/barre_etat.dart';
import '../../theme/animations.dart';
import '../../theme/identite.dart';
import '../../theme/motif.dart';
import '../../widgets/commun.dart';
import '../commande/ecran_commande.dart';

/// Plan de salle (section 3.1) : vert libre, orange occupée, bleu addition.
class EcranSalle extends ConsumerWidget {
  /// false quand l'écran est intégré dans l'espace administrateur.
  final bool avecBarre;
  const EcranSalle({super.key, this.avecBarre = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corps = const PlanDeSalle();
    if (!avecBarre) return corps;
    return Scaffold(
      appBar: barreBraise(title: const Text('Plan de salle'), actions: actionsBarre(context, ref)),
      body: corps,
    );
  }
}

class PlanDeSalle extends ConsumerStatefulWidget {
  const PlanDeSalle({super.key});
  @override
  ConsumerState<PlanDeSalle> createState() => _PlanDeSalleState();
}

class _PlanDeSalleState extends ConsumerState<PlanDeSalle> {
  String? _zone; // null = toutes

  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(tablesProvider);
    final zones = ref.watch(zonesProvider).value ?? const [];
    final sessions = ref.watch(sessionsEnCoursProvider).value ?? const [];
    final parTable = {
      for (final s in sessions)
        if (s.idTable != null) s.idTable!: s,
    };
    final aEmporter = sessions.where((s) => s.aEmporter).toList();

    return tables.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (liste) {
        final visibles = liste.where((t) => t.active && (_zone == null || t.idZone == _zone)).toList();
        return Column(
          children: [
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _filtre('Toutes', null),
                  for (final z in zones) _filtre(z.nom, z.id),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => _ouvrir(context, null, null),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('À emporter'),
                  ),
                ],
              ),
            ),
            if (aEmporter.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final s in aEmporter)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.shopping_bag),
                          label: Text('${s.numeroTable} · ${fcfa(s.total)}'),
                          onPressed: () => _ouvrir(context, null, s),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: visibles.length,
                itemBuilder: (context, i) {
                  final t = visibles[i];
                  final s = parTable[t.id];
                  return Apparition(
                    index: i,
                    child: CarteTable(
                      table: t,
                      session: s,
                      onTap: () => _ouvrir(context, t, s),
                      onLongPress: s == null ? null : () => _actionsTable(context, t, s, liste, parTable),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Legende(couleurLibre, 'Libre'),
                  _Legende(couleurOccupee, 'Occupée'),
                  _Legende(couleurAddition, 'Addition demandée'),
                  Text(
                    'Appui long : transférer ou fusionner',
                    style: TextStyle(color: identite.texte.withValues(alpha: 0.55)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _filtre(String nom, String? id) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(nom, style: const TextStyle(fontSize: 16)),
      selected: _zone == id,
      onSelected: (_) => setState(() => _zone = id),
    ),
  );

  Future<void> _ouvrir(BuildContext context, TableResto? t, SessionTable? s) async {
    int couverts = 0;
    if (t != null && s == null) {
      // Ouverture de la table : nombre de couverts facultatif.
      final c = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('Ouvrir la table ${t.numero}'),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Nombre de couverts (facultatif)'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 1; i <= 8; i++)
                    SizedBox(
                      width: 56,
                      child: FilledButton.tonal(onPressed: () => Navigator.pop(ctx, i), child: Text('$i')),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Passer')),
            ),
          ],
        ),
      );
      if (c == null) return;
      couverts = c;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EcranCommande(table: t, idSession: s?.id, couverts: couverts),
      ),
    );
  }

  Future<void> _actionsTable(
    BuildContext context,
    TableResto t,
    SessionTable s,
    List<TableResto> toutes,
    Map<String, SessionTable> parTable,
  ) async {
    final acteur = ref.read(acteurProvider)!;
    final svc = ref.read(commandeServiceProvider);
    final choix = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Table ${t.numero}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Transférer vers une table libre'),
              onTap: () => Navigator.pop(ctx, 'transfert'),
            ),
            ListTile(
              leading: const Icon(Icons.merge_type),
              title: const Text('Fusionner avec une autre table'),
              onTap: () => Navigator.pop(ctx, 'fusion'),
            ),
          ],
        ),
      ),
    );
    if (choix == null || !context.mounted) return;
    final candidates = choix == 'transfert'
        ? toutes.where((x) => x.active && x.statut == StatutTable.libre && parTable[x.id] == null).toList()
        : toutes.where((x) => x.id != t.id && parTable[x.id]?.statut == StatutSession.ouverte).toList();
    if (candidates.isEmpty) {
      afficherMessage(context, 'Aucune table disponible', erreur: true);
      return;
    }
    final dest = await showDialog<TableResto>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(choix == 'transfert' ? 'Transférer vers…' : 'Fusionner la table ${t.numero} dans…'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in candidates)
                  SizedBox(
                    width: 72,
                    child: FilledButton.tonal(onPressed: () => Navigator.pop(ctx, c), child: Text(c.numero)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (dest == null || !context.mounted) return;
    await essayer(
      context,
      () => choix == 'transfert' ? svc.transferer(acteur, s, dest) : svc.fusionner(acteur, s, parTable[dest.id]!),
      succes: choix == 'transfert' ? 'Table transférée' : 'Tables fusionnées',
    );
  }
}

class _Legende extends StatelessWidget {
  final Color couleur;
  final String texte;
  const _Legende(this.couleur, this.texte);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(width: 6),
      Text(texte, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}

class CarteTable extends StatelessWidget {
  final TableResto table;
  final SessionTable? session;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const CarteTable({super.key, required this.table, this.session, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final addition = s != null && s.statut != StatutSession.ouverte;
    final couleur = s == null ? couleurLibre : (addition ? couleurAddition : couleurOccupee);
    final rayon = BorderRadius.circular(identite.arrondi);
    final etat = s == null ? 'Libre' : (addition ? 'Addition demandée' : 'Occupée');
    return Semantics(
      button: true,
      label: 'Table ${table.numero} $etat${s == null ? '' : ' ${fcfa(s.total)}'}',
      excludeSemantics: true,
      child: Pulsation(
        active: addition,
        couleur: couleur,
        rayon: rayon,
        child: Pression(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: duree(context, 450),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: rayon,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(couleur, Colors.white, 0.08)!, Color.lerp(couleur, Colors.black, 0.22)!],
              ),
              boxShadow: [
                BoxShadow(color: couleur.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5)),
              ],
            ),
            child: ClipRRect(
              borderRadius: rayon,
              child: Stack(
                children: [
                  // Motif discret dans le coin.
                  Positioned(
                    right: -20,
                    top: -20,
                    width: 90,
                    height: 90,
                    child: CustomPaint(painter: MotifPainter(couleur: Colors.white, opacite: 0.16)),
                  ),
                  // Places assises.
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Row(
                      children: [
                        for (var i = 0; i < table.capacite.clamp(0, 8); i++)
                          Container(
                            margin: const EdgeInsets.only(right: 3),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: s != null && i < s.couverts ? 0.95 : 0.35),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (addition)
                    const Positioned(right: 10, top: 8, child: Icon(Icons.receipt_long, color: Colors.white, size: 20)),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: DefaultTextStyle(
                        style: const TextStyle(color: Colors.white),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              table.numero,
                              style: TextStyle(
                                fontFamily: identite.policeTitres,
                                fontSize: 40,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: duree(context, 300),
                              child: s == null
                                  ? const Text('Libre', key: ValueKey('libre'), style: TextStyle(fontSize: 15))
                                  : Column(
                                      key: const ValueKey('occ'),
                                      children: [
                                        MontantAnime(
                                          s.total,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          '${heure(s.ouverture)} · ${s.nomServeuse}',
                                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
