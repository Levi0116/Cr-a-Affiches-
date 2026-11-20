import { loadFont } from "@remotion/fonts";
import { Easing, interpolate, spring, staticFile } from "remotion";

/** Couleurs de l'identité « Chez les Amani » (logo). */
export const C = {
  orange: "#F55A0A",
  orangeClair: "#FF8A3D",
  vert: "#0B3A1C",
  vertClair: "#1F6B3A",
  creme: "#FFF3D6",
  cremeFonce: "#F3DFB8",
  nuit: "#0B1510",
  nuit2: "#13231A",
  libre: "#059669",
  occupee: "#D97706",
  addition: "#2563EB",
  erreur: "#E5484D",
  blanc: "#FFFFFF",
  accentLumiere: "#FFD08A",
  texte: "#13241A",
};

export const TITRE = "PlusJakarta";
export const TEXTE = "InterUI";
export const ICONES = "MaterialIcons";

loadFont({ family: TITRE, url: staticFile("PlusJakartaSans-800.ttf"), weight: "800" });
loadFont({ family: TITRE, url: staticFile("PlusJakartaSans-700.ttf"), weight: "700" });
loadFont({ family: TEXTE, url: staticFile("Inter-500.ttf"), weight: "500" });
loadFont({ family: TEXTE, url: staticFile("Inter-600.ttf"), weight: "600" });
loadFont({ family: TEXTE, url: staticFile("Inter-700.ttf"), weight: "700" });
loadFont({ family: ICONES, url: staticFile("MaterialIcons-Regular.otf"), weight: "400" });

export const FPS = 30;
/** Une mesure de la musique (104 BPM, 4 temps) en images. */
export const MESURE = (60 / 104) * 4 * FPS;
export const M = (mesures: number) => Math.round(mesures * MESURE);

/** Durées des scènes, calées sur les sections de la musique. */
export const DUREES = {
  intro: M(4),
  probleme: M(11) - M(4),
  concept: M(15) - M(11),
  serveuse: M(20) - M(15),
  caisse: M(25) - M(20),
  stock: M(28) - M(25),
  patron: M(33) - M(28),
  fonctionnalites: M(39) - M(33),
  resultats: M(44) - M(39),
  outro: 3400 - M(44),
};
export const DUREE_TOTALE = Object.values(DUREES).reduce((a, b) => a + b, 0);

export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const easeInOut = Easing.bezier(0.65, 0, 0.35, 1);
export const easeIn = Easing.bezier(0.7, 0, 0.84, 0);

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** 0 → 1 entre `debut` et `debut + duree` (sortie douce). */
export const entre = (f: number, debut: number, duree = 20, easing = easeOut) =>
  interpolate(f, [debut, debut + duree], [0, 1], { ...clamp, easing });

/** 1 → 0 sur les `duree` dernières images avant `fin`. */
export const sort = (f: number, fin: number, duree = 15) =>
  interpolate(f, [fin - duree, fin], [1, 0], { ...clamp, easing: easeIn });

/** Ressort (rebond) démarrant à `debut`. */
export const ressort = (f: number, debut: number, amorti = 11, raideur = 140) =>
  spring({ frame: f - debut, fps: FPS, config: { damping: amorti, stiffness: raideur, mass: 0.8 } });

export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** Codes des icônes Material (police Flutter). */
export const IC = {
  table: 0xf0585,
  doigt: 0xe670,
  ticket: 0xe50d,
  billets: 0xe482,
  partage: 0xe12d,
  stock: 0xe34a,
  cloche: 0xe450,
  bouclier: 0xe69a,
  rapports: 0xe347,
  horsLigne: 0xe6eb,
  qr: 0xe4f6,
  ardoise: 0xe3dd,
  sync: 0xf04ce,
  ok: 0xe159,
  alerte: 0xe6cc,
  appareils: 0xe1cb,
  restaurant: 0xe532,
  bar: 0xe38c,
  epargne: 0xe553,
  eclair: 0xe0ee,
  hausse: 0xe67f,
  equipe: 0xe2ee,
  horloge: 0xe556,
  imprimer: 0xe4ea,
  telephone: 0xe5c6,
  tablette: 0xe63e,
  ordinateur: 0xe1c3,
  nuage: 0xe16f,
  recyclage: 0xf055a,
};

/** 7800 → « 7 800 ». */
export const milliers = (n: number) => Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");
