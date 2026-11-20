import 'package:web/web.dart' as web;

/// Recharge l'application web (nouvelle version publiée sur Hosting).
bool rechargerPage() {
  web.window.location.reload();
  return true;
}
