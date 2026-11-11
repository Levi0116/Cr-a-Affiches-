
// Durée totale : 120 s à 30 i/s
export const TOTAL = 3600;

// Départ de chaque réplique (en images)
export const L = {
  kp1: 30,
  client: 128,
  kp2: 215,
  yao1: 515,
  bravo: 618,
  microbe: 940,
  blesse: 1410,
  tele: 1900,
  g1: 2210,
  yao2: 2460,
  g2: 2695,
  narr: 3186,
} as const;

export const VOIX: { id: string; file: string; at: number; vol: number }[] = [
  { id: "00-kpocle1", file: "voix/00-kpocle1.mp3", at: L.kp1, vol: 0.55 },
  { id: "01-client", file: "voix/01-client.mp3", at: L.client, vol: 0.5 },
  { id: "02-kpocle2", file: "voix/02-kpocle2.mp3", at: L.kp2, vol: 0.55 },
  { id: "03-yao", file: "voix/03-yao.mp3", at: L.yao1, vol: 1 },
  { id: "04-bravo", file: "voix/04-bravo.mp3", at: L.bravo, vol: 1 },
  { id: "05-microbe", file: "voix/05-microbe.mp3", at: L.microbe, vol: 1 },
  { id: "06-blesse", file: "voix/06-blesse.mp3", at: L.blesse, vol: 1.2 },
  { id: "07-tele", file: "voix/07-tele.mp3", at: L.tele, vol: 0.8 },
  { id: "08-gonmon1", file: "voix/08-gonmon1.mp3", at: L.g1, vol: 1 },
  { id: "09-yao", file: "voix/09-yao.mp3", at: L.yao2, vol: 1 },
  { id: "10-gonmon2", file: "voix/10-gonmon2.mp3", at: L.g2, vol: 1 },
  { id: "11-narrateur", file: "voix/11-narrateur.mp3", at: L.narr, vol: 1 },
];

// Effets sonores : fichier, départ, volume, durée max (images), boucle
export const SFX: { f: string; at: number; vol: number; dur?: number; loop?: boolean }[] = [
  { f: "neon", at: 0, vol: 0.35, dur: 300, loop: true },
  { f: "couteau", at: 312, vol: 0.7 },
  { f: "couteau", at: 380, vol: 0.5 },
  { f: "briquet", at: 425, vol: 0.9 },
  { f: "whoosh", at: 798, vol: 0.5 },
  { f: "course", at: 935, vol: 1 },
  { f: "course", at: 985, vol: 0.7 },
  { f: "neon", at: 1110, vol: 0.45, dur: 90 },
  { f: "boitement", at: 1205, vol: 1 },
  { f: "grille", at: 1318, vol: 1 },
  { f: "casiers", at: 1380, vol: 0.9 },
  { f: "impact", at: 1660, vol: 0.9 },
  { f: "whoosh", at: 1672, vol: 0.5 },
  { f: "whoosh", at: 1684, vol: 0.5 },
  { f: "souffle", at: 1690, vol: 0.8 },
  { f: "pneus", at: 1798, vol: 1 },
  { f: "coupure", at: 1888, vol: 0.9 },
  { f: "portiere", at: 2070, vol: 0.9 },
  { f: "grille", at: 2112, vol: 1 },
  { f: "impact", at: 2160, vol: 0.8 },
  { f: "impact", at: 2640, vol: 0.8 },
  { f: "souffle", at: 3030, vol: 1, dur: 65 },
  { f: "impact", at: 2900, vol: 0.5 },
  { f: "gel", at: 3168, vol: 1 },
  { f: "bip", at: 3200, vol: 0.35, dur: 400, loop: true },
];

// Repères de mise en scène
export const T = {
  bravoWalk: [800, 930],
  microbes: [935, 1075],
  kpocleExit: [1035, 1110],
  blesseIn: [1200, 1318],
  gateForce: [1318, 1345],
  blesseHide: [1345, 1392],
  pickup: [1798, 1850],
  gyro: 1832,
  tvFlash: 1888,
  gonmonsOut: [2070, 2112],
  gatePush: [2112, 2135],
  g1Step: [2905, 2935],
  freeze: 3168,
};
