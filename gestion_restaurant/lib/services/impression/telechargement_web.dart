import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Propose le fichier au téléchargement dans le navigateur de la caisse.
Future<bool> telecharger(String nomFichier, List<int> octets, String typeMime) async {
  final blob = web.Blob([Uint8List.fromList(octets).toJS].toJS, web.BlobPropertyBag(type: typeMime));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = nomFichier;
  web.document.body!.append(a);
  a.click();
  a.remove();
  Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return true;
}
