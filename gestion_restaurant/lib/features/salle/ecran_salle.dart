import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
import '../../widgets/barre_etat.dart';
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
      appBar: AppBar(title: const Text('Plan de salle'), actions: actionsBarre(context, ref)),
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
    final parTable = {for (final s in sessions) if (s.idTable != null) s.idTable!: s};
    final aEmporter = sessions.where((s) => s.aEmporter).toList();

    return tables.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (liste) {
        final visibles =
            liste.where((t) => t.active && (_zone == null || t.idZone == _zone)).toList();
        return Column(children: [
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
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: visibles.length,
              itemBuilder: (context, i) {
                final t = visibles[i];
                final s = parTable[t.id];
                return CarteTable(
                  table: t,
                  session: s,
                  onTap: () => _ouvrir(context, t, s),
                  onLongPress: s == null ? null : () => _actionsTable(context, t, s, liste, parTable),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Appui long sur une table occupée : transférer ou fusionner',
                style: TextStyle(color: Colors.grey)),
          ),
        ]);
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
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 1; i <= 8; i++)
                  SizedBox(
                    width: 56,
                    child: FilledButton.tonal(
                        onPressed: () => Navigator.pop(ctx, i), child: Text('$i')),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, 0), child: const Text('Passer')),
            ),
          ],
        ),
      );
      if (c == null) return;
      couverts = c;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EcranCommande(table: t, idSession: s?.id, couverts: couverts),
    ));
  }

  Future<void> _actionsTable(BuildContext context, TableResto t, SessionTable s,
      List<TableResto> toutes, Map<String, SessionTable> parTable) async {
    final acteur = ref.read(acteurProvider)!;
    final svc = ref.read(commandeServiceProvider);
    final choix = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('Table ${t.numero}', style: const TextStyle(fontWeight: FontWeight.bold))),
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
        ]),
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
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in candidates)
                SizedBox(
                  width: 72,
                  child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(ctx, c), child: Text(c.numero)),
                ),
            ]),
          ),
        ],
      ),
    );
    if (dest == null || !context.mounted) return;
    await essayer(
      context,
      () => choix == 'transfert'
          ? svc.transferer(acteur, s, dest)
          : svc.fusionner(acteur, s, parTable[dest.id]!),
      succes: choix == 'transfert' ? 'Table transférée' : 'Tables fusionnées',
    );
  }
}

class CarteTable extends StatelessWidget {
  final TableResto table;
  final SessionTable? session;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const CarteTable(
      {super.key, required this.table, this.session, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final couleur = s == null
        ? couleurLibre
        : (s.statut == StatutSession.ouverte ? couleurOccupee : couleurAddition);
    return Material(
      color: couleur,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(table.numero,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                if (s == null)
                  const Text('Libre', style: TextStyle(fontSize: 15))
                else ...[
                  Text(fcfa(s.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('${heure(s.ouverture)} · ${s.nomServeuse}',
                      style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  if (s.statut != StatutSession.ouverte)
                    const Text('ADDITION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
