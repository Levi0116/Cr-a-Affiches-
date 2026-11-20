{{flutter_js}}
{{flutter_build_config}}

// Application installable (PWA) : notre propre « service worker » garde toute
// l'application en cache pour démarrer sans internet (voir outils/generer-sw.mjs).
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch((e) => console.warn('Service worker non enregistré :', e));
  });
}

_flutter.loader.load({
  onEntrypointLoaded: async (moteur) => {
    const appli = await moteur.initializeEngine();
    await appli.runApp();
    document.getElementById('demarrage')?.classList.add('fini');
    setTimeout(() => document.getElementById('demarrage')?.remove(), 600);
  },
});
