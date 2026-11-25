import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/pin.dart';
import '../../models/modeles.dart';
import '../../services/db.dart';
import '../../state/providers.dart';
import '../../widgets/banniere_version.dart';
import '../../widgets/barre_etat.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../theme/motif.dart';
import '../admin/ecran_admin.dart';
import '../caisse/ecran_caisse.dart';
import '../salle/ecran_salle.dart';
import '../stock/ecran_stock.dart';

/// Racine : écran de connexion, ou espace de l'employé connecté, avec
/// déconnexion automatique après quelques minutes d'inactivité (section 2.1).
class Accueil extends ConsumerStatefulWidget {
  const Accueil({super.key});
  @override
  ConsumerState<Accueil> createState() => _AccueilState();
}

class _AccueilState extends ConsumerState<Accueil> {
  Timer? _minuteur;

  void _relancer() {
    _minuteur?.cancel();
    if (ref.read(utilisateurProvider) == null) return;
    final minutes = ref.read(restaurantProvider).value?.deconnexionMinutes ?? 5;
    _minuteur = Timer(Duration(minutes: minutes), () {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(utilisateurProvider.notifier).deconnecter();
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(utilisateurProvider, (_, _) => _relancer());
    final e = ref.watch(utilisateurProvider);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _relancer(),
      child: Column(
        children: [
          const BanniereVersion(),
          Expanded(
            child: e == null ? Theme(data: AppTheme.sombre, child: const EcranConnexion()) : EspaceEmploye(employe: e),
          ),
        ],
      ),
    );
  }
}

class EspaceEmploye extends StatelessWidget {
  final Employe employe;
  const EspaceEmploye({super.key, required this.employe});

  @override
  Widget build(BuildContext context) => switch (employe.role) {
    Role.serveuse => const EcranSalle(),
    Role.caissier => const EcranCaisse(),
    Role.gestionnaire => const EcranStock(),
    Role.admin => const EcranAdmin(),
  };
}

class EcranConnexion extends ConsumerStatefulWidget {
  const EcranConnexion({super.key});
  @override
  ConsumerState<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends ConsumerState<EcranConnexion> {
  final _secousse = GlobalKey<ShakeWrapperState>();
  Employe? _choisi;
  String _pin = '';
  String? _erreur;

  bool _verification = false;

  void _touche(String c) {
    if (_verification) return;
    if (c == '✓') {
      _verifier();
      return;
    }
    setState(() {
      _erreur = null;
      if (c == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        return;
      }
      if (_pin.length < pinMax) _pin += c;
    });
  }

  /// Vérification par le serveur (en ligne) ou sur l'appareil (hors ligne).
  Future<void> _verifier() async {
    if (!mounted || _choisi == null) return;
    if (_pin.length < pinMin) {
      setState(() => _erreur = 'Le code contient au moins $pinMin chiffres');
      _secousse.currentState?.secouer();
      return;
    }
    final e = _choisi!;
    setState(() => _verification = true);
    try {
      final c = await ref.read(serveurAppareilsProvider).connecter(e, _pin);
      if (!mounted) return;
      ref.read(utilisateurProvider.notifier).connecter(c.employe);
    } on ErreurMetier catch (err) {
      if (!mounted) return;
      _secousse.currentState?.secouer();
      setState(() {
        _pin = '';
        _erreur = err.message;
      });
    } finally {
      if (mounted) setState(() => _verification = false);
    }
  }

  String get _salutation {
    final h = DateTime.now().hour;
    return h < 12 ? 'BONJOUR' : (h < 18 ? 'BON APRÈS-MIDI' : 'BONSOIR');
  }

  bool _compact = false;

  @override
  Widget build(BuildContext context) {
    final employes = ref.watch(employesProvider);
    final resto = ref.watch(restaurantProvider).value;
    _compact = MediaQuery.sizeOf(context).height < 900;
    final compactPin = _compact && _choisi != null;
    final large = MediaQuery.sizeOf(context).width >= 1000;
    // Poste de l'appareil : seuls les comptes de ce poste sont proposés.
    final postes = ref.watch(serveurAppareilsProvider).postes;
    final contenu = employes.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Erreur : $e', style: const TextStyle(color: Colors.white)),
      data: (liste) => AnimatedSwitcher(
        duration: duree(context, 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: _choisi == null
            ? _choixEmploye(
                liste.where((e) => e.actif && (postes == null || postes.contains(e.role))).toList(),
                postes,
              )
            : _pave(_choisi!),
      ),
    );
    final zone = Stack(
      children: [
        // Halo de braise derrière le contenu.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.1,
                colors: [identite.principale.withValues(alpha: 0.10), identite.nuit.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.topRight,
                child: Padding(padding: EdgeInsets.all(14), child: IndicateurConnexion()),
              ),
              if (!large && !compactPin) ...[
                Hero(tag: 'logo', child: LogoResto(nom: resto?.nom ?? '', taille: _compact ? 96 : 120)),
                const SizedBox(height: 12),
                const TitreMarque(taille: 24),
                const SizedBox(height: 18),
              ],
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: contenu,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: identite.nuit,
      body: large
          ? Row(
              children: [
                const Expanded(flex: 5, child: _PanneauMarque()),
                Expanded(flex: 6, child: zone),
              ],
            )
          : FondMotif(couleurFond: identite.nuit, couleurMotif: identite.or, opacite: 0.06, child: zone),
    );
  }

  Widget _choixEmploye(List<Employe> actifs, Set<Role>? postes) => Column(
    key: const ValueKey('choix'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(_salutation, style: AppTypo.surTitre(identite.or, taille: 13)),
      const SizedBox(height: 6),
      Text('Qui prend son poste ?', textAlign: TextAlign.center, style: AppTypo.marque(identite.texteSombre, taille: 34)),
      if (postes != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: identite.or.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: identite.or.withValues(alpha: 0.4)),
          ),
          child: Text(
            'Poste de cet appareil : ${postes.map((r) => r.libelle).join(' · ')}',
            style: AppTypo.etiquette(identite.or, taille: 13),
          ),
        ),
      ],
      const SizedBox(height: 26),
      if (actifs.isEmpty)
        Text(
          'Aucun compte pour ce poste.\nL’administrateur crée les comptes dans Administration → Comptes de l’équipe.',
          textAlign: TextAlign.center,
          style: AppTypo.etiquette(identite.texteSombre.withValues(alpha: 0.7), taille: 15, poids: FontWeight.w500),
        ),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < actifs.length; i++)
            StaggeredEntrance(
              index: i,
              child: BouncyTapWrapper(
                onTap: () => setState(() => _choisi = actifs[i]),
                child: _CarteEmploye(employe: actifs[i]),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _pave(Employe e) => Column(
    key: ValueKey('pin-${e.id}'),
    mainAxisSize: MainAxisSize.min,
    children: [
      _Avatar(employe: e, taille: _compact ? 48 : 64),
      const SizedBox(height: 8),
      Text(e.nom, style: AppTypo.marque(identite.texteSombre, taille: 30)),
      Text('Tapez votre code personnel puis ✓', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
      const SizedBox(height: 18),
      ShakeWrapper(
        key: _secousse,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < (_pin.length < pinMin ? pinMin : _pin.length); i++)
              AnimatedContainer(
                duration: duree(context, 220),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.all(7),
                width: i < _pin.length ? 20 : 14,
                height: i < _pin.length ? 20 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _erreur != null ? identite.erreur : (i < _pin.length ? identite.accent : Colors.transparent),
                  border: Border.all(color: identite.accent, width: 2),
                  boxShadow: i < _pin.length
                      ? [BoxShadow(color: identite.accent.withValues(alpha: 0.6), blurRadius: 12)]
                      : null,
                ),
              ),
          ],
        ),
      ),
      SizedBox(
        height: 26,
        child: AnimatedOpacity(
          opacity: _erreur == null ? 0 : 1,
          duration: duree(context, 200),
          child: Text(
            _erreur ?? '',
            style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        width: _compact ? 264 : 300,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', '✓'])
              c.isEmpty
                  ? const SizedBox()
                  : Semantics(
                      container: true,
                      button: true,
                      label: c == '⌫' ? 'Effacer' : (c == '✓' ? 'Valider' : c),
                      excludeSemantics: true,
                      child: BouncyTapWrapper(
                        scale: 0.88,
                        onTap: () => _touche(c),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c == '✓' ? identite.principale : Colors.white.withValues(alpha: c == '⌫' ? 0.04 : 0.09),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: c == '⌫'
                              ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 26)
                              : c == '✓'
                              ? (_verification
                                    ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                    : const Icon(Icons.check_rounded, color: Colors.white, size: 32))
                              : Text(
                                  c,
                                  style: TextStyle(
                                    fontFamily: identite.policeTitres,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: identite.accent),
        onPressed: () => setState(() {
          _choisi = null;
          _pin = '';
          _erreur = null;
        }),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Changer de personne'),
      ),
    ],
  );
}

IconData _iconeRole(Role r) => switch (r) {
  Role.serveuse => Icons.room_service_rounded,
  Role.caissier => Icons.point_of_sale_rounded,
  Role.gestionnaire => Icons.inventory_2_rounded,
  Role.admin => Icons.workspace_premium_rounded,
};

Color _couleurRole(Role r) => switch (r) {
  Role.serveuse => identite.principale,
  Role.caissier => identite.tableAddition,
  Role.gestionnaire => identite.tableLibre,
  Role.admin => Color.lerp(identite.secondaire, Colors.white, 0.18)!,
};

class _Avatar extends StatelessWidget {
  final Employe employe;
  final double taille;
  const _Avatar({required this.employe, this.taille = 52});
  @override
  Widget build(BuildContext context) {
    final c = _couleurRole(employe.role);
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [c, Color.lerp(c, Colors.black, 0.3)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
      ),
      child: Text(
        employe.nom.characters.first.toUpperCase(),
        style: TextStyle(
          fontFamily: identite.policeTitres,
          fontWeight: FontWeight.w800,
          fontSize: taille * 0.45,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CarteEmploye extends StatelessWidget {
  final Employe employe;
  const _CarteEmploye({required this.employe});
  @override
  Widget build(BuildContext context) {
    final c = _couleurRole(employe.role);
    return Semantics(
      container: true,
      button: true,
      label: '${employe.nom} ${employe.role.libelle}',
      child: Container(
        width: 176,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: identite.surfaceSombre,
          borderRadius: BorderRadius.circular(identite.arrondi),
          border: Border.all(color: identite.accent.withValues(alpha: 0.12)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            // Bandeau de couleur du rôle, avec un fragment du motif.
            Container(
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c, Color.lerp(c, identite.nuit, 0.45)!]),
              ),
              child: CustomPaint(painter: MotifPainter(couleur: Colors.white, opacite: 0.16), size: const Size(176, 46)),
            ),
            Transform.translate(offset: const Offset(0, -26), child: _Avatar(employe: employe, taille: 58)),
            Transform.translate(
              offset: const Offset(0, -18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    Text(
                      employe.nom,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypo.titre(identite.texteSombre, taille: 19, poids: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconeRole(employe.role), size: 14, color: Color.lerp(c, Colors.white, 0.35)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              employe.role.libelle,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypo.etiquette(Color.lerp(c, Colors.white, 0.55)!, taille: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panneau de marque (grand écran) : logo, nom, slogan, prestations.
class _PanneauMarque extends StatelessWidget {
  const _PanneauMarque();

  @override
  Widget build(BuildContext context) {
    final prestations = [
      (Icons.restaurant_menu_rounded, 'Cuisine ivoirienne'),
      (Icons.outdoor_grill_rounded, 'Grillades'),
      (Icons.local_bar_rounded, 'Boissons'),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [identite.secondaire, const Color(0xFF082A14), identite.nuit],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: FondMotif(couleurMotif: identite.or, opacite: 0.07, child: const SizedBox.expand())),
          // Grand cercle de braise en arrière-plan.
          Positioned(
            right: -160,
            top: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [identite.principale.withValues(alpha: 0.30), identite.principale.withValues(alpha: 0)]),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 40, 48, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: duree(context, 1100),
                    curve: Curves.elasticOut,
                    builder: (_, v, c) => Transform.scale(scale: 0.5 + 0.5 * v, alignment: Alignment.centerLeft, child: c),
                    child: const Hero(tag: 'logo', child: LogoResto(nom: '', taille: 176)),
                  ),
                  const SizedBox(height: 28),
                  StaggeredEntrance(index: 1, child: const TitreMarque(taille: 44, alignement: CrossAxisAlignment.start)),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < prestations.length; i++)
                        StaggeredEntrance(
                          index: i + 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: identite.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: identite.or.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(prestations[i].$1, size: 18, color: identite.or),
                                const SizedBox(width: 8),
                                Text(prestations[i].$2, style: AppTypo.etiquette(identite.texteSombre, taille: 14)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text('Espace équipe · ${identite.nomRestaurant}', style: AppTypo.etiquette(identite.texteSombre.withValues(alpha: 0.5), taille: 12)),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          const Align(alignment: Alignment.bottomCenter, child: BandeKita(hauteur: 10)),
        ],
      ),
    );
  }
}
