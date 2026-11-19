import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/db.dart';
import '../../services/serveur_appareils.dart';
import '../../theme/animated_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/identite.dart';
import '../../theme/motif.dart';

/// Première mise en service d'un appareil (section 2.1) : l'administrateur
/// affiche un QR code (Administration → Appareils) ; on le scanne, ou on
/// tape les 6 caractères. Une seule fois par appareil.
class EcranLiaison extends StatefulWidget {
  final ServeurAppareils serveur;
  final ValueChanged<EtatAppareil> onLie;
  const EcranLiaison({super.key, required this.serveur, required this.onLie});

  @override
  State<EcranLiaison> createState() => _EcranLiaisonState();
}

class _EcranLiaisonState extends State<EcranLiaison> {
  final _ctrl = TextEditingController();
  final _secousse = GlobalKey<ShakeWrapperState>();
  bool _envoi = false;
  String? _erreur;

  bool get _cameraDisponible => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  Future<void> _lier([String? code]) async {
    final c = (code ?? _ctrl.text).trim().toUpperCase();
    if (c.length != 6) {
      setState(() => _erreur = 'Le code comporte 6 caractères');
      _secousse.currentState?.secouer();
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final etat = await widget.serveur.lier(c);
      if (!mounted) return;
      showSuccessBurst(context, 'Appareil lié');
      await Future<void>.delayed(duree(context, 900));
      widget.onLie(etat);
    } on ErreurMetier catch (e) {
      setState(() => _erreur = e.message);
      _secousse.currentState?.secouer();
    } catch (_) {
      setState(() => _erreur = 'Connexion impossible : vérifiez le Wi-Fi ou les données mobiles.');
      _secousse.currentState?.secouer();
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _scanner() async {
    final brut = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _Scanner()));
    if (brut == null) return;
    final code = CodeLiaison.lireQr(brut);
    if (code == null) {
      setState(() => _erreur = 'Ce QR code n’est pas un code de liaison');
      return;
    }
    _ctrl.text = code;
    await _lier(code);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.sombre,
      child: Builder(
        builder: (context) {
          final p = context.pal;
          return Scaffold(
            backgroundColor: identite.nuit,
            body: FondMotif(
              couleurFond: identite.nuit,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const LogoResto(nom: '', taille: 130),
                          const SizedBox(height: 22),
                          Text('Lier cet appareil', style: AppTypo.titre(Colors.white, taille: 28)),
                          const SizedBox(height: 8),
                          Text(
                            'Sur l’ordinateur de la caisse, l’administrateur ouvre Administration → Appareils → « Lier un appareil ».',
                            textAlign: TextAlign.center,
                            style: AppTypo.etiquette(p.texteSecondaire, taille: 15, poids: FontWeight.w500),
                          ),
                          const SizedBox(height: 26),
                          if (_cameraDisponible) ...[
                            SizedBox(
                              width: double.infinity,
                              child: GradientActionButton(
                                label: 'Scanner le QR code',
                                icone: Icons.qr_code_scanner_rounded,
                                hauteur: 60,
                                onPressed: _envoi ? null : _scanner,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text('ou tapez le code', style: AppTypo.etiquette(p.texteDiscret, taille: 14)),
                            const SizedBox(height: 10),
                          ],
                          ShakeWrapper(
                            key: _secousse,
                            child: TextField(
                              controller: _ctrl,
                              textAlign: TextAlign.center,
                              maxLength: 6,
                              autofocus: !_cameraDisponible,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                                TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
                              ],
                              style: AppTypo.montant(Colors.white, taille: 34).copyWith(letterSpacing: 14),
                              decoration: InputDecoration(counterText: '', hintText: '••••••', errorText: _erreur),
                              onSubmitted: (_) => _lier(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _envoi ? null : _lier,
                              child: _envoi
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    )
                                  : const Text('Lier avec ce code'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Scanner extends StatefulWidget {
  const _Scanner();
  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  bool _fini = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Scanner le QR code'), backgroundColor: Colors.black),
    body: Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          onDetect: (capture) {
            final v = capture.barcodes.firstOrNull?.rawValue;
            if (v == null || _fini) return;
            _fini = true;
            HapticFeedback.mediumImpact();
            Navigator.pop(context, v);
          },
        ),
        // Cadre de visée.
        IgnorePointer(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: identite.principale, width: 4),
            ),
          ),
        ),
      ],
    ),
  );
}
