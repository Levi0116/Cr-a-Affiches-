import { creerPool, migrer } from '../src/bd.js';
import { lireConfig } from '../src/config.js';

const cfg = lireConfig();
const pool = creerPool(cfg.mysql);
await migrer(pool);
console.log('Base à jour.');
await pool.end();
