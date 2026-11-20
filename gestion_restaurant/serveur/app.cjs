// Point d'entrée pour les hébergements cPanel « Setup Node.js App » (Passenger),
// qui chargent un fichier CommonJS : il démarre simplement le serveur (module ES).
import('./src/index.js').catch((e) => {
  console.error(e);
  process.exit(1);
});
