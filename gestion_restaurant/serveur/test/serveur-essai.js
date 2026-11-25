// Serveur d'essai pour le test d'intégration Flutter (test/synchro_test.dart) :
// base de test vierge, deux codes de liaison, puis attend.
import { nouveauCode } from '../src/securite.js';
import { demarrer, PIN_SERVEUSE, RID } from './outils.js';

const t = await demarrer();
const codes = [];
for (let i = 0; i < 4; i++) {
  const code = nouveauCode();
  await t.pool.query('INSERT INTO codes_liaison (code, restaurant_id, nom, type, admin, expire) VALUES (?, ?, ?, ?, 0, ?)', [
    code, RID, `Tablette ${i + 1}`, 'tablette', new Date(Date.now() + 600_000),
  ]);
  codes.push(code);
}
process.stdout.write(JSON.stringify({ port: t.port, codes, idServeuse: t.idServeuse, pinServeuse: PIN_SERVEUSE }) + '\n');
process.stdin.resume();
process.stdin.on('end', async () => {
  await t.fermer();
  process.exit(0);
});
