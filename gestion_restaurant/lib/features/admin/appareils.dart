import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../models/modeles.dart';
import '../../services/serveur_appareils.dart';
import '../../state/providers.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../widgets/commun.dart';
import '../../widgets/panneaux.dart';

/// Appareils liés au restaurant (section 3.4) : liaison par QR code,
/// retrait à distance d'un appareil perdu ou volé.
class PageAppareils extends ConsumerWidget {
  const PageAppareils({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final async = ref.watch(appareilsProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        EnTetePage(
          titre: 'Appareils',
          description: 'Tablettes, ordinateur de caisse et téléphones liés au restaurant. Un appareil perdu se retire en un clic.',
          action: GradientActionButton(
            label: 'Lier un appareil',
            icone: Icons.qr_code_2_rounded,
            onPressed: () => _lier(context, ref),
          ),
        ),
        async.when(
          loading: () => const Chargement(),
          error: (e, _) => Chargement(erreur: e),
          data: (liste) {
            if (liste.isEmpty) {
              return PanneauCaisse(
                child: Text(
                  'Aucun appareil lié pour l’instant.',
                  style: AppTypo.etiquette(p.texteSecondaire, taille: 15),
                ),
              );
            }
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final (i, a) in liste.indexed)
                  SizedBox(
                    width: 340,
                    child: StaggeredEntrance(
                      index: i,
                      child: _CarteAppareil(appareil: a, onRetirer: () => _retirer(context, ref, a)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _lier(BuildContext context, WidgetRef ref) async {
    final nom = TextEditingController();
    var type = TypeAppareil.tablette;
    var admin = false;
    // Poste de l'appareil : seuls ces comptes pourront s'y connecter.
    var postes = <Role>{Role.serveuse};
    Set<Role> parDefaut(TypeAppareil t, bool adm) => adm
        ? {Role.admin}
        : switch (t) {
            TypeAppareil.tablette => {Role.serveuse},
            TypeAppareil.caisse => {Role.caissier},
            TypeAppareil.telephone => {Role.serveuse},
          };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Lier un appareil'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nom,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nom (ex. Tablette terrasse)'),
                ),
                const SizedBox(height: 14),
                SegmentedButton<TypeAppareil>(
                  segments: const [
                    ButtonSegment(
                      value: TypeAppareil.tablette,
                      icon: Icon(Icons.tablet_android_rounded),
                      label: Text('Tablette'),
                    ),
                    ButtonSegment(
                      value: TypeAppareil.caisse,
                      icon: Icon(Icons.desktop_windows_rounded),
                      label: Text('Caisse'),
                    ),
                    ButtonSegment(
                      value: TypeAppareil.telephone,
                      icon: Icon(Icons.smartphone_rounded),
                      label: Text('Téléphone'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setState(() {
                    type = v.first;
                    if (type != TypeAppareil.telephone) admin = false;
                    postes = parDefaut(type, admin);
                  }),
                ),
                if (type == TypeAppareil.telephone)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Téléphone du gérant'),
                    subtitle: const Text('Droits administrateur permanents et notifications'),
                    value: admin,
                    onChanged: (v) => setState(() {
                      admin = v;
                      postes = parDefaut(type, admin);
                    }),
                  ),
                const SizedBox(height: 12),
                Text('Poste de l’appareil', style: AppTypo.etiquette(context.pal.texte, taille: 14, poids: FontWeight.w700)),
                Text(
                  'Seuls les comptes de ces postes apparaîtront et pourront se connecter sur cet appareil.',
                  style: AppTypo.etiquette(context.pal.texteSecondaire, taille: 12, poids: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in Role.values)
                      FilterChip(
                        label: Text(r.libelle),
                        selected: postes.contains(r),
                        onSelected: (r == Role.admin && admin)
                            ? null
                            : (v) => setState(() => v ? postes.add(r) : postes.remove(r)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer le code')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (postes.isEmpty) {
      afficherMessage(context, 'Choisissez au moins un poste pour cet appareil', erreur: true);
      return;
    }
    final code = await essayer(
      context,
      () => ref.read(serveurAppareilsProvider).creerCode(nom: nom.text, type: type, admin: admin, postes: postes),
    );
    if (code == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _DialogueQr(code: code, nom: nom.text.trim()),
    );
  }

  Future<void> _retirer(BuildContext context, WidgetRef ref, Appareil a) async {
    final ok = await confirmer(
      context,
      'Retirer « ${a.nom} » ?',
      'L’appareil est déconnecté et ne pourra plus accéder aux données du restaurant. Il faudra le lier à nouveau pour le réutiliser.',
    );
    if (!ok || !context.mounted) return;
    await essayer(context, () => ref.read(serveurAppareilsProvider).revoquer(a.uid), succes: 'Appareil retiré');
  }
}

class _CarteAppareil extends StatelessWidget {
  final Appareil appareil;
  final VoidCallback onRetirer;
  const _CarteAppareil({required this.appareil, required this.onRetirer});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final a = appareil;
    final icone = switch (a.type) {
      TypeAppareil.tablette => Icons.tablet_android_rounded,
      TypeAppareil.caisse => Icons.desktop_windows_rounded,
      TypeAppareil.telephone => Icons.smartphone_rounded,
    };
    final c = a.actif ? p.libre : p.texteDiscret;
    return AnimatedOpacity(
      opacity: a.actif ? 1 : 0.6,
      duration: duree(context, 300),
      child: PanneauCaisse(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: a.actif ? degradePrincipal(identite.secondaire) : null,
                color: a.actif ? null : p.fond,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icone, color: a.actif ? Colors.white : p.texteDiscret),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.nom, style: AppTypo.etiquette(p.texte, taille: 16, poids: FontWeight.w700)),
                  Text(
                    '${a.type.libelle}${a.admin ? ' · administrateur' : ''}'
                    '${a.postes == null ? ' · tous les postes' : ' · poste : ${a.postes!.map((r) => r.libelle).join(', ')}'}',
                    style: AppTypo.etiquette(p.texteSecondaire, taille: 13, poids: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(a.actif ? Icons.check_circle_rounded : Icons.block_rounded, size: 14, color: c),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          a.actif ? 'Actif${a.lieLe == null ? '' : ' · lié le ${dateCourte(a.lieLe!)}'}' : 'Retiré',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypo.chiffres(AppTypo.etiquette(c, taille: 12, poids: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (a.actif)
              IconButton(
                tooltip: 'Retirer cet appareil',
                onPressed: onRetirer,
                icon: Icon(Icons.link_off_rounded, color: p.erreur),
              ),
          ],
        ),
      ),
    );
  }
}

/// QR code + code à 6 caractères + compte à rebours de validité.
class _DialogueQr extends StatefulWidget {
  final CodeLiaison code;
  final String nom;
  const _DialogueQr({required this.code, required this.nom});
  @override
  State<_DialogueQr> createState() => _DialogueQrState();
}

class _DialogueQrState extends State<_DialogueQr> {
  late Timer _t;
  Duration _reste = Duration.zero;

  @override
  void initState() {
    super.initState();
    _maj();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _maj());
  }

  void _maj() {
    final r = widget.code.expire.difference(DateTime.now());
    if (mounted) setState(() => _reste = r.isNegative ? Duration.zero : r);
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final expire = _reste == Duration.zero;
    final mm = _reste.inMinutes.toString().padLeft(2, '0');
    final ss = (_reste.inSeconds % 60).toString().padLeft(2, '0');
    return AlertDialog(
      title: Text('Lier « ${widget.nom} »'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sur l’appareil, ouvrez l’application puis scannez ce code (ou tapez les 6 caractères).',
              textAlign: TextAlign.center,
              style: AppTypo.etiquette(p.texteSecondaire, taille: 14, poids: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: expire ? 0.15 : 1,
              duration: duree(context, 300),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(identite.arrondi),
                  border: Border.all(color: p.bordure),
                ),
                child: QrImageView(
                  data: widget.code.contenuQr,
                  size: 220,
                  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: identite.secondaire),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: identite.secondaire,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(widget.code.code, style: AppTypo.montant(p.texte, taille: 34).copyWith(letterSpacing: 10)),
            const SizedBox(height: 6),
            Text(
              expire ? 'Code expiré : créez-en un nouveau' : 'Valable encore $mm:$ss · usage unique',
              style: AppTypo.chiffres(AppTypo.etiquette(expire ? p.erreur : p.texteSecondaire, taille: 13)),
            ),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Terminé'))],
    );
  }
}
