// Préchargé dans la CLI Firebase pendant les tests (NODE_OPTIONS --require).
//
// La CLI envoie toutes ses requêtes au proxy HTTPS de l'environnement, même
// celles destinées à ses propres émulateurs sur 127.0.0.1, sans lire
// NO_PROXY. Ce module laisse passer en direct le seul trafic local (boucle
// locale) ; tout le reste continue de passer par le proxy.
const racine = process.env.FIREBASE_TOOLS_DIR;
let undici = null;
try {
  if (racine) undici = require(require.resolve('undici', { paths: [racine] }));
} catch {
  // CLI installée autrement (ou sans undici) : aucun correctif nécessaire.
}
if (undici) {
  const ProxyAgentOrigine = undici.ProxyAgent;
  const direct = new undici.Agent();
  const LOCAUX = new Set(['127.0.0.1', 'localhost', '::1', '[::1]']);
  class ProxyAgentSaufLocal extends undici.Dispatcher {
    constructor(opts) {
      super();
      this.proxy = new ProxyAgentOrigine(opts);
    }
    dispatch(options, handler) {
      const hote = new URL(options.origin).hostname;
      return (LOCAUX.has(hote) ? direct : this.proxy).dispatch(options, handler);
    }
    close() {
      return this.proxy.close();
    }
    destroy(err) {
      return this.proxy.destroy(err);
    }
  }
  undici.ProxyAgent = ProxyAgentSaufLocal;
}
