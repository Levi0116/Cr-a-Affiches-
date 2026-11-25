-- Schéma MySQL 8 (utf8mb4). Appliqué par `npm run migrer` (idempotent).

CREATE TABLE IF NOT EXISTS restaurants (
  id VARCHAR(40) PRIMARY KEY,
  nom VARCHAR(120) NOT NULL,
  rev BIGINT UNSIGNED NOT NULL DEFAULT 0,
  cree_le TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Données du restaurant (menu, tables, commandes, factures, stock…).
-- Chaque écriture reçoit un numéro de révision croissant : les appareils
-- demandent « tout ce qui a changé depuis la révision N » (synchronisation).
CREATE TABLE IF NOT EXISTS documents (
  restaurant_id VARCHAR(40) NOT NULL,
  chemin VARCHAR(255) NOT NULL,
  collection VARCHAR(60) NOT NULL,
  donnees JSON NOT NULL,
  rev BIGINT UNSIGNED NOT NULL,
  maj TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (restaurant_id, chemin),
  KEY idx_rev (restaurant_id, rev),
  KEY idx_collection (restaurant_id, collection),
  CONSTRAINT fk_doc_resto FOREIGN KEY (restaurant_id) REFERENCES restaurants(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Lots d'écritures déjà appliqués (un lot renvoyé après une coupure n'est
-- jamais appliqué deux fois).
CREATE TABLE IF NOT EXISTS lots_appliques (
  restaurant_id VARCHAR(40) NOT NULL,
  id_lot CHAR(36) NOT NULL,
  resultat JSON NOT NULL,
  applique_le TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (restaurant_id, id_lot)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Appareils liés. Le jeton n'est jamais stocké en clair (empreinte SHA-256).
CREATE TABLE IF NOT EXISTS appareils (
  id CHAR(36) PRIMARY KEY,
  restaurant_id VARCHAR(40) NOT NULL,
  nom VARCHAR(80) NOT NULL,
  type ENUM('tablette','caisse','telephone') NOT NULL,
  admin TINYINT(1) NOT NULL DEFAULT 0,
  jeton_empreinte CHAR(64) NOT NULL UNIQUE,
  revoque TINYINT(1) NOT NULL DEFAULT 0,
  cree_le TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  vu_le TIMESTAMP(3) NULL,
  KEY idx_resto (restaurant_id),
  CONSTRAINT fk_app_resto FOREIGN KEY (restaurant_id) REFERENCES restaurants(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Codes de liaison (valables 15 minutes, usage unique).
CREATE TABLE IF NOT EXISTS codes_liaison (
  code CHAR(8) PRIMARY KEY,
  restaurant_id VARCHAR(40) NOT NULL,
  nom VARCHAR(80) NOT NULL,
  type ENUM('tablette','caisse','telephone') NOT NULL,
  admin TINYINT(1) NOT NULL DEFAULT 0,
  expire TIMESTAMP(3) NOT NULL,
  utilise TINYINT(1) NOT NULL DEFAULT 0,
  CONSTRAINT fk_code_resto FOREIGN KEY (restaurant_id) REFERENCES restaurants(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Essais de code PIN (blocage après plusieurs erreurs).
CREATE TABLE IF NOT EXISTS essais_pin (
  restaurant_id VARCHAR(40) NOT NULL,
  employe_id CHAR(36) NOT NULL,
  echecs INT NOT NULL DEFAULT 0,
  bloque_jusqua TIMESTAMP(3) NULL,
  PRIMARY KEY (restaurant_id, employe_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
