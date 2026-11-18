import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Imprime le ticket via une iframe cachée. Avec Chrome lancé en
/// `--kiosk-printing`, il part directement sur l'imprimante thermique par
/// défaut, sans fenêtre de confirmation (section 4.6).
Future<bool> imprimerHtml(String html) async {
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  iframe.style
    ..position = 'fixed'
    ..right = '0'
    ..bottom = '0'
    ..width = '0'
    ..height = '0'
    ..border = '0';
  final charge = Completer<void>();
  iframe.onload = ((web.Event _) {
    if (!charge.isCompleted) charge.complete();
  }).toJS;
  iframe.srcdoc = html.toJS;
  web.document.body!.append(iframe);
  await charge.future.timeout(const Duration(seconds: 5), onTimeout: () {});
  iframe.contentWindow?.focus();
  iframe.contentWindow?.print();
  Timer(const Duration(seconds: 60), () => iframe.remove());
  return true;
}
