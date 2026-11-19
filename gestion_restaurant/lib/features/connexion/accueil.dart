import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/pin.dart';
import '../../models/modeles.dart';
import '../../state/providers.dart';
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
      child: e == null ? Theme(data: AppTheme.sombre, child: const EcranConnexion()) : EspaceEmploye(employe: e),
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

  void _touche(String c) {
    setState(() {
      _erreur = null;
      if (c == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        return;
      }
      if (_pin.length < 4) _pin += c;
    });
    if (_pin.length == 4) {
      // Laisse le 4e point s'allumer avant de vérifier.
      Future.delayed(duree(context, 160), _verifier);
    }
  }

  void _verifier() {
    if (!mounted || _choisi == null) return;
    final e = _choisi!;
    final db = ref.read(dbProvider);
    // Vérification locale du code haché : fonctionne hors ligne.
    final ok = hacherPin(idRestaurant: db.idRestaurant, idEmploye: e.id, pin: _pin) == e.pinHash;
    if (ok) {
      ref.read(utilisateurProvider.notifier).connecter(e);
    } else {
      _secousse.currentState?.secouer();
      setState(() {
        _pin = '';
        _erreur = 'Code incorrect';
      });
    }
  }

  String get _salutation {
    final h = DateTime.now().hour;
    return h < 12 ? 'Bonjour' : (h < 18 ? 'Bon après-midi' : 'Bonsoir');
  }

  bool _compact = false;

  @override
  Widget build(BuildContext context) {
    final employes = ref.watch(employesProvider);
    final resto = ref.watch(restaurantProvider).value;
    _compact = MediaQuery.sizeOf(context).height < 900;
    final compactPin = _compact && _choisi != null;
    return Scaffold(
      backgroundColor: identite.nuit,
      body: FondMotif(
        couleurFond: identite.nuit,
        opacite: 0.08,
        child: SafeArea(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.topRight,
                child: Padding(padding: EdgeInsets.all(12), child: IndicateurConnexion()),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: duree(context, 900),
                          curve: Curves.elasticOut,
                          builder: (_, v, c) => Transform.scale(scale: 0.4 + 0.6 * v, child: c),
                          child: AnimatedSize(
                            duration: duree(context, 300),
                            child: compactPin
                                ? const SizedBox.shrink()
                                : DecoratedBox(
                                    // Halo orange chaud derrière le logo.
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: AppOmbres.lueur(identite.principale, force: 1.4),
                                    ),
                                    child: Hero(
                                      tag: 'logo',
                                      child: LogoResto(
                                        nom: resto?.nom ?? '',
                                        taille: identite.logoAsset == null
                                            ? (_compact ? 84 : 104)
                                            : (_compact ? 150 : 190),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: compactPin ? 0 : 12),
                        // Le logo contient déjà le nom : on ne le répète pas.
                        if (!compactPin && identite.logoAsset == null)
                          Text(
                            resto?.nom ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: identite.policeTitres,
                              fontWeight: FontWeight.w800,
                              fontSize: 30,
                              color: Colors.white,
                            ),
                          ),
                        SizedBox(height: compactPin ? 0 : 24),
                        employes.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (e, _) => Text('Erreur : $e', style: const TextStyle(color: Colors.white)),
                          data: (liste) => AnimatedSwitcher(
                            duration: duree(context, 380),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child),
                            ),
                            child: _choisi == null
                                ? _choixEmploye(liste.where((e) => e.actif).toList())
                                : _pave(_choisi!),
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
    );
  }

  Widget _choixEmploye(List<Employe> actifs) => Column(
    key: const ValueKey('choix'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$_salutation ! Qui prend son poste ?',
        style: TextStyle(color: identite.accent, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 20),
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
      Text(
        e.nom,
        style: TextStyle(
          fontFamily: identite.policeTitres,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      Text('Tapez votre code à 4 chiffres', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
      const SizedBox(height: 18),
      ShakeWrapper(
        key: _secousse,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 4; i++)
              AnimatedContainer(
                duration: duree(context, 220),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.all(9),
                width: i < _pin.length ? 22 : 16,
                height: i < _pin.length ? 22 : 16,
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
            for (final c in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'])
              c.isEmpty
                  ? const SizedBox()
                  : Semantics(
                      container: true,
                      button: true,
                      label: c == '⌫' ? 'Effacer' : c,
                      excludeSemantics: true,
                      child: BouncyTapWrapper(
                        scale: 0.88,
                        onTap: () => _touche(c),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: c == '⌫' ? 0.04 : 0.09),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: c == '⌫'
                              ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 26)
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
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: '${employe.nom} ${employe.role.libelle}',
    child: Container(
      width: 168,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(identite.arrondi),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          _Avatar(employe: employe),
          const SizedBox(height: 10),
          Text(
            employe.nom,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconeRole(employe.role), size: 15, color: _couleurRole(employe.role)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  employe.role.libelle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
