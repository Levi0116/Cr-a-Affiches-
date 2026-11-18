import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/calculs.dart';
import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../services/impression/impression.dart';
import '../../services/ticket.dart';
import '../../state/providers.dart';
import '../../widgets/barre_etat.dart';
import '../../widgets/commun.dart';

Future<void> imprimer(BuildContext context, String html) async {
  final ok = await imprimerHtml(html);
  if (!ok && context.mounted) {
    afficherMessage(context, 'Impression disponible sur l’ordinateur de la caisse');
  }
}

/// Module Caisse (section 3.2).
class EcranCaisse extends ConsumerWidget {
  final bool avecBarre;
  const EcranCaisse({super.key, this.avecBarre = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Alerte sonore discrète quand une addition est demandée.
    ref.listen(sessionsEnCoursProvider, (avant, apres) {
      int n(AsyncValue<List<SessionTable>>? v) =>
          v?.value?.where((s) => s.statut == StatutSession.addition).length ?? 0;
      if (n(apres) > n(avant)) SystemSound.play(SystemSoundType.alert);
    });
    final corps = DefaultTabController(
      length: 4,
      child: Column(children: [
        const _BandeauJournee(),
        const TabBar(isScrollable: true, tabs: [
          Tab(text: 'Tables ouvertes'),
          Tab(text: 'Factures du jour'),
          Tab(text: 'Ardoises'),
          Tab(text: 'Ouverture / clôture'),
        ]),
        const Expanded(
          child: TabBarView(children: [
            _TablesOuvertes(),
            _FacturesDuJour(),
            _Ardoises(),
            _Journee(),
          ]),
        ),
      ]),
    );
    if (!avecBarre) return corps;
    return Scaffold(
      appBar: AppBar(title: const Text('Caisse'), actions: actionsBarre(context, ref)),
      body: corps,
    );
  }
}

class _BandeauJournee extends ConsumerWidget {
  const _BandeauJournee();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final j = ref.watch(journeeOuverteProvider);
    if (j.isLoading) return const SizedBox.shrink();
    final journee = j.value;
    if (journee != null) {
      return Container(
        width: double.infinity,
        color: couleurLibre.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
            'Caisse ouverte depuis ${dateHeure(journee.ouverture)} · fond ${fcfa(journee.fond)} · encaissé ${fcfa(journee.totalEncaisse)}'),
      );
    }
    return MaterialBanner(
      content: const Text('La caisse est fermée : saisissez le fond de caisse pour encaisser.'),
      actions: [
        FilledButton(
          onPressed: () => ouvrirCaisse(context, ref),
          child: const Text('Ouvrir la caisse'),
        ),
      ],
    );
  }
}

Future<void> ouvrirCaisse(BuildContext context, WidgetRef ref) async {
  final fond = await demanderNombre(context, 'Ouverture de caisse', label: 'Fond de caisse (F)');
  if (fond == null || !context.mounted) return;
  await essayer(context, () => ref.read(caisseServiceProvider).ouvrirCaisse(ref.read(acteurProvider)!, fond),
      succes: 'Caisse ouverte');
}

// ------------------------------------------------------------ Tables ouvertes

class _TablesOuvertes extends ConsumerStatefulWidget {
  const _TablesOuvertes();
  @override
  ConsumerState<_TablesOuvertes> createState() => _TablesOuvertesState();
}

class _TablesOuvertesState extends ConsumerState<_TablesOuvertes> {
  String? _selection;

  int _priorite(SessionTable s) => switch (s.statut) {
        StatutSession.addition => 0,
        StatutSession.facturee => 1,
        _ => 2,
      };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionsEnCoursProvider);
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (sessions) {
        final triees = [...sessions]..sort((a, b) {
            final p = _priorite(a).compareTo(_priorite(b));
            return p != 0 ? p : a.ouverture.compareTo(b.ouverture);
          });
        final choisie = triees.where((s) => s.id == _selection).firstOrNull;
        final large = MediaQuery.sizeOf(context).width >= 900;
        final liste = triees.isEmpty
            ? const Center(child: Text('Aucune table ouverte'))
            : ListView.separated(
                itemCount: triees.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = triees[i];
                  final couleur = s.statut == StatutSession.ouverte ? couleurOccupee : couleurAddition;
                  return ListTile(
                    selected: s.id == _selection,
                    leading: CircleAvatar(
                      backgroundColor: couleur,
                      foregroundColor: Colors.white,
                      child: Text(s.aEmporter ? '🛍' : s.numeroTable,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(s.aEmporter ? s.numeroTable : 'Table ${s.numeroTable}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${s.nomServeuse} · ouverte à ${heure(s.ouverture)} · ${s.nbTours} tour(s)'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(fcfa(s.total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        if (s.statut == StatutSession.addition) const Pastille('Addition demandée', couleurAddition),
                        if (s.statut == StatutSession.facturee) const Pastille('Facturée', couleurAddition),
                      ],
                    ),
                    onTap: () {
                      if (large) {
                        setState(() => _selection = s.id);
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: Text('Table ${s.numeroTable}')),
                            body: _DetailSessionParId(idSession: s.id),
                          ),
                        ));
                      }
                    },
                  );
                },
              );
        if (!large) return liste;
        return Row(children: [
          SizedBox(width: 400, child: liste),
          const VerticalDivider(width: 1),
          Expanded(
            child: choisie == null
                ? const Center(child: Text('Choisissez une table'))
                : DetailSession(session: choisie, key: ValueKey(choisie.id)),
          ),
        ]);
      },
    );
  }
}

class _DetailSessionParId extends ConsumerWidget {
  final String idSession;
  const _DetailSessionParId({required this.idSession});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = (ref.watch(sessionsEnCoursProvider).value ?? const [])
        .where((x) => x.id == idSession)
        .firstOrNull;
    if (s == null) return const Center(child: Text('Addition close'));
    return DetailSession(session: s);
  }
}

/// Ticket provisoire de la table, rempli automatiquement à chaque tour.
class DetailSession extends ConsumerWidget {
  final SessionTable session;
  const DetailSession({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    final lignes = ref.watch(lignesProvider(s.id)).value ?? const [];
    final factures = ref.watch(facturesSessionProvider(s.id)).value ?? const [];
    final resto = ref.watch(restaurantProvider).value;
    final journee = ref.watch(journeeOuverteProvider).value;
    final acteur = ref.watch(acteurProvider)!;
    final aFacturer = lignes.where((l) => !l.annulee && l.idFacture == null).toList();
    final tot = calculerTotaux(aFacturer.map((l) => l.calcul),
        remise: s.remise, tauxTva: resto?.tauxTvaEffectif ?? 0);
    final tours = <int, List<LigneCommande>>{};
    for (final l in lignes) {
      tours.putIfAbsent(l.tour, () => []).add(l);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.aEmporter ? s.numeroTable : 'Table ${s.numeroTable}',
            style: Theme.of(context).textTheme.headlineSmall),
        Text('Serveuse : ${s.nomServeuse} · ouverte à ${heure(s.ouverture)}'
            '${s.couverts > 0 ? ' · ${s.couverts} couverts' : ''}'),
        const SizedBox(height: 12),
        for (final e in tours.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Tour ${e.key} · ${heure(e.value.first.heure)} · ${e.value.first.auteur}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final l in e.value)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${l.quantite} × ${l.nom}${l.offert ? ' (offert)' : ''}'
                  '${l.idFacture != null ? ' · facturé' : ''}',
                  style: l.annulee
                      ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                      : null),
              subtitle: l.annulee
                  ? Text('Annulé : ${l.motifAnnulation} · validé par ${l.validePar}')
                  : (l.note.isNotEmpty ? Text('« ${l.note} »') : null),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(fcfa(l.montant)),
                if (!l.annulee && !l.offert && l.idFacture == null)
                  PopupMenuButton<String>(
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'offert', child: Text('Offrir (validation admin)')),
                    ],
                    onSelected: (_) async {
                      final motif = await demanderTexte(context, 'Offrir ${l.nom}', label: 'Motif');
                      if (motif == null || !context.mounted) return;
                      await essayer(context,
                          () => ref.read(caisseServiceProvider).demanderOffert(acteur, s, l, motif),
                          succes: 'Demande envoyée à l’administrateur');
                    },
                  ),
              ]),
            ),
        ],
        const Divider(height: 32),
        _ligneTotal('Sous-total', tot.sousTotal),
        if (tot.remise > 0) _ligneTotal('Remise (${s.remise!.motif}, validée par ${s.remise!.validePar})', -tot.remise),
        if (tot.tva > 0) _ligneTotal('dont TVA', tot.tva),
        _ligneTotal('Reste à facturer', tot.total, gros: true),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long),
            label: const Text('Pré-addition'),
            onPressed: resto == null || aFacturer.isEmpty
                ? null
                : () => imprimer(context, ticketPreAddition(resto, s, aFacturer, tot.total)),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.percent),
            label: const Text('Remise'),
            onPressed: s.statut == StatutSession.facturee ? null : () => _demanderRemise(context, ref),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.request_quote),
            label: const Text('Facture finale'),
            onPressed: resto == null || aFacturer.isEmpty ? null : () => _facturer(context, ref, resto, aFacturer),
          ),
        ]),
        if (factures.isNotEmpty) ...[
          const Divider(height: 32),
          Text('Factures', style: Theme.of(context).textTheme.titleMedium),
          for (final f in factures) CarteFacture(facture: f, journee: journee),
        ],
      ],
    );
  }

  Widget _ligneTotal(String libelle, int montant, {bool gros = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(libelle, style: TextStyle(fontSize: gros ? 20 : 15))),
          Text(fcfa(montant),
              style: TextStyle(fontSize: gros ? 26 : 15, fontWeight: gros ? FontWeight.bold : null)),
        ]),
      );

  Future<void> _demanderRemise(BuildContext context, WidgetRef ref) async {
    var type = TypeRemise.montant;
    final valeur = TextEditingController();
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Demander une remise'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<TypeRemise>(
              segments: const [
                ButtonSegment(value: TypeRemise.montant, label: Text('Montant (F)')),
                ButtonSegment(value: TypeRemise.pourcentage, label: Text('Pourcentage')),
              ],
              selected: {type},
              onSelectionChanged: (v) => setState(() => type = v.first),
            ),
            TextField(
              controller: valeur,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: type == TypeRemise.montant ? 'Montant' : '%'),
            ),
            TextField(controller: motif, decoration: const InputDecoration(labelText: 'Motif (obligatoire)')),
            const SizedBox(height: 8),
            const Text('La remise sera appliquée après validation de l’administrateur.'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await essayer(
      context,
      () => ref.read(caisseServiceProvider).demanderRemise(ref.read(acteurProvider)!, session,
          type: type, valeur: int.tryParse(valeur.text) ?? 0, motif: motif.text),
      succes: 'Demande de remise envoyée',
    );
  }

  Future<void> _facturer(
      BuildContext context, WidgetRef ref, Restaurant resto, List<LigneCommande> aFacturer) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Facture finale'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'tout'),
            child: const ListTile(leading: Icon(Icons.receipt), title: Text('Une seule facture')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'parts'),
            child: const ListTile(leading: Icon(Icons.call_split), title: Text('Partager en parts égales')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'articles'),
            child: const ListTile(leading: Icon(Icons.checklist), title: Text('Partager par article')),
          ),
        ],
      ),
    );
    if (mode == null || !context.mounted) return;
    int parts = 1;
    Set<String>? ids;
    if (mode == 'parts') {
      final n = await demanderNombre(context, 'Nombre de parts', initial: 2);
      if (n == null || n < 2) return;
      parts = n;
    } else if (mode == 'articles') {
      ids = await _choisirLignes(context, aFacturer);
      if (ids == null || ids.isEmpty) return;
    }
    if (!context.mounted) return;
    final caisse = ref.read(caisseServiceProvider);
    await essayer(
      context,
      () => caisse.emettreFactures(
          caissier: ref.read(acteurProvider)!,
          session: session,
          restaurant: resto,
          idsLignes: ids,
          nombreParts: parts),
      succes: 'Facture émise : encaissez ou mettez en ardoise',
    );
  }

  Future<Set<String>?> _choisirLignes(BuildContext context, List<LigneCommande> lignes) {
    final choix = <String>{};
    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final total = lignes.where((l) => choix.contains(l.id)).fold(0, (s, l) => s + l.montant);
          return AlertDialog(
            title: const Text('Articles de cette part'),
            content: SizedBox(
              width: 400,
              child: ListView(shrinkWrap: true, children: [
                for (final l in lignes)
                  CheckboxListTile(
                    value: choix.contains(l.id),
                    onChanged: (v) => setState(() => v! ? choix.add(l.id) : choix.remove(l.id)),
                    title: Text('${l.quantite} × ${l.nom}'),
                    secondary: Text(fcfa(l.montant)),
                  ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(ctx, choix), child: Text('Facturer ${fcfa(total)}')),
            ],
          );
        },
      ),
    );
  }
}

/// Une facture émise : encaissement, ardoise, réimpression, avoir.
class CarteFacture extends ConsumerWidget {
  final Facture facture;
  final JourneeCaisse? journee;
  const CarteFacture({super.key, required this.facture, this.journee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = facture;
    final resto = ref.watch(restaurantProvider).value;
    final acteur = ref.watch(acteurProvider)!;
    final (libelle, couleur) = switch (f.statut) {
      StatutFacture.emise => ('À encaisser', couleurOccupee),
      StatutFacture.payee => ('Payée', couleurLibre),
      StatutFacture.credit => ('À crédit', couleurAddition),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${f.numero}${f.partie != null ? ' (part ${f.partie})' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Pastille(libelle, couleur),
          ]),
          Text('Table ${f.numeroTable} · ${dateHeure(f.date)} · ${f.nomCaissier}'),
          Text(fcfa(f.total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (f.statut == StatutFacture.payee)
            Text('Reçu ${fcfa(f.montantRecu)} · rendu ${fcfa(f.monnaieRendue)}'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (f.statut == StatutFacture.emise) ...[
              FilledButton.icon(
                icon: const Icon(Icons.payments),
                label: const Text('Encaisser'),
                onPressed: journee == null || resto == null
                    ? () => afficherMessage(context, 'Ouvrez d’abord la caisse', erreur: true)
                    : () => _encaisser(context, ref, resto),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.menu_book),
                label: const Text('Ardoise'),
                onPressed: resto == null ? null : () => _ardoise(context, ref, resto),
              ),
            ] else
              OutlinedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Duplicata'),
                onPressed: resto == null
                    ? null
                    : () async {
                        await ref.read(caisseServiceProvider).noterReimpression(acteur, f);
                        if (context.mounted) await imprimer(context, ticketFacture(resto, f, duplicata: true));
                      },
              ),
            if (acteur.estAdmin && f.statut == StatutFacture.payee)
              OutlinedButton.icon(
                icon: const Icon(Icons.undo),
                label: const Text('Avoir'),
                onPressed: () => _avoir(context, ref),
              ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _encaisser(BuildContext context, WidgetRef ref, Restaurant resto) async {
    final f = facture;
    final ctrl = TextEditingController();
    final recu = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        final montant = int.tryParse(ctrl.text) ?? 0;
        final monnaie = montant - f.total;
        // Billets courants en FCFA.
        final suggestions = <int>{
          f.total,
          for (final b in [500, 1000, 2000, 5000, 10000])
            if (b >= f.total) b else ((f.total + b - 1) ~/ b) * b,
        }.toList()
          ..sort();
        return AlertDialog(
          title: Text('Encaisser ${fcfa(f.total)}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 28),
              decoration: const InputDecoration(labelText: 'Montant reçu (F)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in suggestions.take(5))
                ActionChip(
                  label: Text(fcfa(s)),
                  onPressed: () => setState(() => ctrl.text = '$s'),
                ),
            ]),
            const SizedBox(height: 16),
            Text(
              monnaie >= 0 ? 'Monnaie à rendre : ${fcfa(monnaie)}' : 'Manque ${fcfa(-monnaie)}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: monnaie >= 0 ? couleurLibre : Colors.red),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: monnaie >= 0 && montant > 0 ? () => Navigator.pop(ctx, montant) : null,
              child: const Text('Valider le paiement'),
            ),
          ],
        );
      }),
    );
    if (recu == null || !context.mounted) return;
    final caisse = ref.read(caisseServiceProvider);
    final monnaie = await essayer(
      context,
      () => caisse.encaisser(
          caissier: ref.read(acteurProvider)!, facture: f, montantRecu: recu, journee: journee!),
    );
    if (monnaie == null || !context.mounted) return;
    afficherMessage(context, 'Payée · monnaie à rendre : ${fcfa(monnaie)}');
    final payee = Facture.fromDoc(await ref.read(dbProvider).factures.doc(f.id).get());
    if (context.mounted) await imprimer(context, ticketFacture(resto, payee));
  }

  Future<void> _ardoise(BuildContext context, WidgetRef ref, Restaurant resto) async {
    final ardoises = ref.read(ardoisesProvider).value ?? const [];
    final client = TextEditingController();
    final tel = TextEditingController();
    final choix = await showDialog<Object>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mettre en ardoise (crédit client)'),
        content: SizedBox(
          width: 420,
          child: ListView(shrinkWrap: true, children: [
            if (ardoises.isNotEmpty) const Text('Client existant'),
            for (final a in ardoises)
              ListTile(
                title: Text(a.client),
                subtitle: Text('${a.telephone} · doit ${fcfa(a.montantDu)}'),
                onTap: () => Navigator.pop(ctx, a),
              ),
            const Divider(),
            const Text('Nouveau client'),
            TextField(controller: client, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(
                controller: tel,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'nouveau'), child: const Text('Créer l’ardoise')),
        ],
      ),
    );
    if (choix == null || !context.mounted) return;
    final caisse = ref.read(caisseServiceProvider);
    final acteur = ref.read(acteurProvider)!;
    final ok = await essayer(
      context,
      () async {
        await caisse.mettreEnArdoise(
          caissier: acteur,
          facture: facture,
          idArdoise: choix is Ardoise ? choix.id : null,
          client: client.text,
          telephone: tel.text,
        );
        return true;
      },
      succes: 'Facture mise en ardoise',
    );
    if (ok != true || !context.mounted) return;
    final f = Facture.fromDoc(await ref.read(dbProvider).factures.doc(facture.id).get());
    if (context.mounted) await imprimer(context, ticketFacture(resto, f));
  }

  Future<void> _avoir(BuildContext context, WidgetRef ref) async {
    final montant = await demanderNombre(context, 'Avoir sur ${facture.numero}',
        label: 'Montant à rembourser (F)', initial: facture.total);
    if (montant == null || !context.mounted) return;
    final motif = await demanderTexte(context, 'Motif de l’avoir', label: 'Motif');
    if (motif == null || !context.mounted) return;
    final caisse = ref.read(caisseServiceProvider);
    await essayer(context,
        () => caisse.creerAvoir(ref.read(acteurProvider)!, facture, montant, motif),
        succes: 'Avoir créé');
  }
}

// ---------------------------------------------------------- Factures du jour

class _FacturesDuJour extends ConsumerWidget {
  const _FacturesDuJour();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(facturesDepuisProvider(debutJour()));
    final journee = ref.watch(journeeOuverteProvider).value;
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (factures) {
        if (factures.isEmpty) return const Center(child: Text('Aucune facture aujourd’hui'));
        final paye = factures.where((f) => f.statut == StatutFacture.payee).fold(0, (s, f) => s + f.total);
        return ListView(padding: const EdgeInsets.all(12), children: [
          Text('${factures.length} facture(s) · ${fcfa(paye)} payés',
              style: Theme.of(context).textTheme.titleMedium),
          for (final f in factures) CarteFacture(facture: f, journee: journee),
        ]);
      },
    );
  }
}

// ------------------------------------------------------------------ Ardoises

class _Ardoises extends ConsumerWidget {
  const _Ardoises();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ardoisesProvider);
    final journee = ref.watch(journeeOuverteProvider).value;
    return async.when(
      loading: () => const Chargement(),
      error: (e, _) => Chargement(erreur: e),
      data: (liste) {
        final enCours = liste.where((a) => a.montantDu > 0).toList();
        if (enCours.isEmpty) return const Center(child: Text('Aucune ardoise en cours'));
        final total = enCours.fold(0, (s, a) => s + a.montantDu);
        return ListView(padding: const EdgeInsets.all(12), children: [
          Text('Total dû : ${fcfa(total)}', style: Theme.of(context).textTheme.titleMedium),
          for (final a in enCours)
            Card(
              child: ListTile(
                title: Text(a.client),
                subtitle: Text('${a.telephone} · depuis ${DateTime.now().difference(a.creeLe).inDays} jour(s)'
                    ' · ${a.idsFactures.length} facture(s)'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(fcfa(a.montantDu), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (journee == null) {
                        afficherMessage(context, 'Ouvrez d’abord la caisse', erreur: true);
                        return;
                      }
                      final m = await demanderNombre(context, 'Remboursement de ${a.client}',
                          label: 'Montant reçu (F)', initial: a.montantDu);
                      if (m == null || !context.mounted) return;
                      await essayer(
                          context,
                          () => ref.read(caisseServiceProvider).rembourserArdoise(
                              caissier: ref.read(acteurProvider)!, ardoise: a, montant: m, journee: journee),
                          succes: 'Remboursement enregistré');
                    },
                    child: const Text('Rembourser'),
                  ),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------- Ouverture/clôture

class _Journee extends ConsumerWidget {
  const _Journee();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final j = ref.watch(journeeOuverteProvider).value;
    final historique = ref.watch(journeesProvider).value ?? const [];
    final enCours = ref.watch(sessionsEnCoursProvider).value ?? const [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (j == null)
        FilledButton.icon(
          icon: const Icon(Icons.lock_open),
          label: const Text('Ouvrir la caisse'),
          onPressed: () => ouvrirCaisse(context, ref),
        )
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Journée en cours', style: Theme.of(context).textTheme.titleLarge),
              Text('Ouverte le ${dateHeure(j.ouverture)} par ${j.caissier}'),
              const SizedBox(height: 8),
              Text('Fond de caisse : ${fcfa(j.fond)}'),
              Text('Encaissements : ${fcfa(j.totalEncaisse)}'),
              Text('Total théorique : ${fcfa(j.fond + j.totalEncaisse)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.lock),
                label: const Text('Clôturer la caisse'),
                onPressed: () => _cloturer(context, ref, j, enCours.length),
              ),
            ]),
          ),
        ),
      const SizedBox(height: 24),
      Text('Historique des clôtures', style: Theme.of(context).textTheme.titleMedium),
      for (final h in historique.where((h) => h.verrouillee))
        ListTile(
          title: Text('${dateHeure(h.ouverture)} → ${h.cloture == null ? '' : dateHeure(h.cloture!)}'),
          subtitle: Text('Théorique ${fcfa(h.totalTheorique)} · compté ${fcfa(h.totalCompte ?? 0)} · ${h.caissier}'),
          trailing: Text('Écart ${fcfa(h.ecart ?? 0)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: (h.ecart ?? 0) == 0 ? couleurLibre : Colors.red)),
        ),
    ]);
  }

  Future<void> _cloturer(BuildContext context, WidgetRef ref, JourneeCaisse j, int tablesOuvertes) async {
    if (tablesOuvertes > 0) {
      final ok = await confirmer(context, 'Tables encore ouvertes',
          '$tablesOuvertes addition(s) ne sont pas réglées. Clôturer quand même ?');
      if (!ok || !context.mounted) return;
    }
    final compte = await demanderNombre(context, 'Clôture de caisse',
        label: 'Argent compté (F)', aide: 'Comptez l’argent présent dans la caisse.');
    if (compte == null || !context.mounted) return;
    final resto = ref.read(restaurantProvider).value;
    final db = ref.read(dbProvider);
    final caisse = ref.read(caisseServiceProvider);
    final cloturee = await essayer(context, () => caisse.cloturerCaisse(ref.read(acteurProvider)!, j, compte));
    if (cloturee == null || !context.mounted) return;
    final nb = (await db.encaissements.where('idJournee', isEqualTo: j.id).get()).docs.length;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Caisse clôturée'),
        content: Text('Théorique : ${fcfa(cloturee.totalTheorique)}\n'
            'Compté : ${fcfa(compte)}\n'
            'Écart : ${fcfa(cloturee.ecart ?? 0)}'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (resto != null && context.mounted) {
      await imprimer(context, ticketCloture(resto, cloturee, nbFactures: nb));
    }
  }
}
