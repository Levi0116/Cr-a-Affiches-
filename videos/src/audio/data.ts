// Vidéo « Sound Collection » (JBL, Harman Kardon, Bose, Apple) – Zeynab Store
// Voix off : voice-audio.json (ElevenLabs) ou voice-audio-pico.json (gratuite : bash make-voice-pico.sh voice-audio-pico.json public/audio/vo src/audio-voice.json)
import VOICE from '../audio-voice.json';

// Un plan du passage produit : extrait de vidéo, ou photo animée (zoom / recadrage)
export type Shot =
  | {video: string; w: number; h: number; from: number; to: number; cx?: number; cy?: number; zoom?: number; fit?: 'contain'}
  | {img: string; w: number; h: number; z0: number; z1: number; cx?: number; cy?: number; dur: number; studio?: boolean};

export type AP = {
  id: keyof typeof VOICE;
  brand: 'JBL' | 'HARMAN KARDON' | 'BOSE' | 'APPLE';
  model: string;
  kind: string;
  price: string;
  accent: string;
  photo: string; // public/audio/photos/…
  cutout: boolean;
  badge?: string;
  specs: {k: string; v: string}[];
  shots: Shot[];
};

const V = (video: string, w: number, h: number, from: number, to: number, o: Partial<{cx: number; cy: number; zoom: number; fit: 'contain'}> = {}): Shot => ({video, w, h, from, to, ...o});
// photo détourée sur fond studio : plan d'ensemble + gros plans
const P = (img: string, w: number, h: number, z0: number, z1: number, cx: number, cy: number, dur: number): Shot => ({img: 'audio/photos/' + img, w, h, z0, z1, cx, cy, dur, studio: true});

const T770 = 'audio/src/tune770.mp4', JR = 'audio/src/jr470.mp4', HP = 'audio/src/homepod.mp4', BO = 'audio/src/bose.mp4';

export const PRODUCTS_A: AP[] = [
  {
    id: 'jr470', brand: 'JBL', model: 'JR 470NC', kind: 'CASQUE ENFANT', price: '65 000', accent: '#ff5a36', photo: 'jr470.png', cutout: true, badge: 'KIDS',
    specs: [{k: 'ANC', v: 'Réduction de bruit active'}, {k: 'PROTECTION', v: 'Volume limité 85 dB'}, {k: 'AUTONOMIE', v: "Jusqu'à 50 h"}, {k: 'MICRO', v: 'Appels & cours en ligne'}, {k: 'DESIGN', v: 'Pliable · léger'}, {k: 'CONNEXION', v: 'Bluetooth 5.3'}],
    shots: [V(JR, 1080, 1920, 0.3, 4.2), V(JR, 1080, 1920, 9.0, 13.0), V(JR, 1080, 1920, 31.0, 35.5), V(JR, 1080, 1920, 40.0, 44.0), V(JR, 1080, 1920, 49.0, 53.0)],
  },
  {
    id: 'tune770', brand: 'JBL', model: 'TUNE 770NC', kind: 'CASQUE SANS FIL', price: '70 000', accent: '#ff7a1a', photo: 'tune770.png', cutout: true,
    specs: [{k: 'ANC', v: 'Adaptative'}, {k: 'SON', v: 'JBL Pure Bass'}, {k: 'AUTONOMIE', v: "Jusqu'à 70 h"}, {k: 'CHARGE RAPIDE', v: '5 min = 3 h'}, {k: 'MULTIPOINT', v: '2 appareils'}, {k: 'DESIGN', v: 'Pliable · confortable'}],
    shots: [V(T770, 720, 1280, 3.0, 5.6, {cy: 0.4}), V(T770, 720, 1280, 13.2, 17.2, {cy: 0.4}), V(T770, 720, 1280, 21.5, 25.0, {cy: 0.4}), V(T770, 720, 1280, 31.0, 35.0, {cy: 0.4}), V(T770, 720, 1280, 36.0, 37.6, {cy: 0.4})],
  },
  {
    id: 'mic', brand: 'JBL', model: 'WIRELESS MIC', kind: 'MICROS SANS FIL', price: '90 000', accent: '#ff9a1a', photo: 'mic.png', cutout: true, badge: 'KARAOKÉ',
    specs: [{k: 'PACK', v: '2 micros + récepteur'}, {k: 'BRANCHEMENT', v: "Prêt à l'emploi"}, {k: 'COMPATIBLE', v: 'JBL PartyBox'}, {k: 'AUTONOMIE', v: '6 h'}, {k: 'RECHARGE', v: 'USB-C'}, {k: 'USAGE', v: 'Karaoké · soirées'}],
    shots: [V('audio/src/mic.mp4', 720, 1280, 0.0, 3.0, {cy: 0.5}), V('audio/src/mic.mp4', 720, 1280, 3.6, 6.0, {cy: 0.5}), V('audio/src/mic.mp4', 720, 1280, 6.4, 8.6, {cy: 0.5}), V('audio/src/mic.mp4', 720, 1280, 8.8, 10.4, {cy: 0.5})],
  },
  {
    id: 'flip7', brand: 'JBL', model: 'FLIP 7', kind: 'ENCEINTE PORTABLE', price: '95 000', accent: '#ff2a4d', photo: 'flip7.png', cutout: true, badge: 'NOUVEAU',
    specs: [{k: 'SON', v: 'AI Sound Boost'}, {k: 'ÉTANCHE', v: 'IP68'}, {k: 'ROBUSTE', v: 'Résiste aux chutes'}, {k: 'AUTONOMIE', v: "Jusqu'à 16 h"}, {k: 'ACCESSOIRE', v: 'Mousqueton amovible'}, {k: 'CONNEXION', v: 'Auracast'}],
    shots: [V('audio/src/flip7.mp4', 720, 1280, 8.1, 9.7, {cy: 0.5}), V('audio/src/flip7.mp4', 720, 1280, 11.6, 12.4, {cy: 0.5}), V('audio/src/flip7.mp4', 720, 1280, 13.3, 15.0, {cy: 0.5}), V('audio/src/flip7.mp4', 720, 1280, 17.0, 18.5, {cy: 0.5}), V('audio/src/flip7.mp4', 720, 1280, 21.0, 22.4, {cy: 0.5}), V('audio/src/flip7.mp4', 720, 1280, 24.9, 25.9, {cy: 0.5})],
  },
  {
    id: 'charge6', brand: 'JBL', model: 'CHARGE 6', kind: 'ENCEINTE PORTABLE', price: '130 000', accent: '#ff8a00', photo: 'charge6.png', cutout: true,
    specs: [{k: 'AUTONOMIE', v: "Jusqu'à 28 h"}, {k: 'ÉTANCHE', v: 'IP68'}, {k: 'ROBUSTE', v: 'Résiste aux chutes'}, {k: 'SON', v: 'AI Sound Boost'}, {k: 'POWERBANK', v: 'Recharge ton téléphone'}, {k: 'SANGLE', v: 'Amovible'}],
    shots: [V('audio/src/charge6.mp4', 720, 1280, 0.6, 4.6, {cy: 0.5}), V('audio/src/charge6.mp4', 720, 1280, 7.0, 11.0, {cy: 0.52}), V('audio/src/charge6.mp4', 720, 1280, 12.0, 16.0, {cy: 0.5})],
  },
  {
    id: 'pulse5', brand: 'JBL', model: 'PULSE 5', kind: 'ENCEINTE LUMINEUSE', price: '130 000', accent: '#c43cff', photo: 'pulse5.png', cutout: true,
    specs: [{k: 'SON', v: '360° · 40 W'}, {k: 'LUMIÈRE', v: 'Show synchronisé'}, {k: 'ÉTANCHE', v: 'IP67'}, {k: 'AUTONOMIE', v: '12 h'}, {k: 'PARTYBOOST', v: 'Relie plusieurs enceintes'}, {k: 'APPLI', v: 'JBL Portable'}],
    shots: [V('audio/src/pulse5.mp4', 720, 1280, 7.5, 11.5, {cy: 0.5}), V('audio/src/pulse5.mp4', 720, 1280, 18.5, 22.5, {cy: 0.5}), V('audio/src/pulse5.mp4', 720, 1280, 30.0, 33.5, {cy: 0.6}), V('audio/src/pulse5.mp4', 720, 1280, 38.6, 42.0, {cy: 0.6})],
  },
  {
    id: 'xtreme3', brand: 'JBL', model: 'XTREME 3', kind: 'ENCEINTE PORTABLE', price: '150 000', accent: '#2f7bff', photo: 'xtreme3.png', cutout: true,
    specs: [{k: 'BASSES', v: '2 radiateurs passifs'}, {k: 'ÉTANCHE', v: 'IP67'}, {k: 'AUTONOMIE', v: '15 h'}, {k: 'POWERBANK', v: 'Intégré'}, {k: 'TRANSPORT', v: 'Bandoulière incluse'}, {k: 'PARTYBOOST', v: 'Multi-enceintes'}],
    shots: [V('audio/src/xtreme3.mp4', 1080, 1920, 2.0, 4.6, {cy: 0.5}), V('audio/src/xtreme3.mp4', 1080, 1920, 7.4, 9.8, {cy: 0.5}), V('audio/src/xtreme3.mp4', 1080, 1920, 13.0, 14.6, {cy: 0.5}), V('audio/src/xtreme3.mp4', 1080, 1920, 15.6, 17.8, {cy: 0.5}), V('audio/src/xtreme3.mp4', 1080, 1920, 25.0, 28.0, {cy: 0.5})],
  },
  {
    id: 'xtreme4', brand: 'JBL', model: 'XTREME 4', kind: 'ENCEINTE PORTABLE', price: '190 000', accent: '#ffb020', photo: 'xtreme4.png', cutout: true, badge: 'NOUVEAU',
    specs: [{k: 'SON', v: 'AI Sound Boost'}, {k: 'BATTERIE', v: 'Remplaçable'}, {k: 'AUTONOMIE', v: "Jusqu'à 24 h"}, {k: 'ÉTANCHE', v: 'IP67'}, {k: 'CONNEXION', v: 'Auracast'}, {k: 'TRANSPORT', v: 'Bandoulière'}],
    shots: [V('audio/src/xtreme4.mp4', 1080, 1920, 0.0, 3.0, {cy: 0.45}), V('audio/src/xtreme4.mp4', 1080, 1920, 3.0, 7.0, {cy: 0.48}), V('audio/src/xtreme4.mp4', 1080, 1920, 9.6, 14.6, {cy: 0.45})],
  },
  {
    id: 'boombox3', brand: 'JBL', model: 'BOOMBOX 3', kind: 'ENCEINTE XXL', price: '280 000', accent: '#ff4d2e', photo: 'boombox3.jpg', cutout: false,
    specs: [{k: 'BASSES', v: 'Massives · 3 voies'}, {k: 'AUTONOMIE', v: '24 h'}, {k: 'ÉTANCHE', v: 'IP67'}, {k: 'POWERBANK', v: 'Intégré'}, {k: 'POIGNÉE', v: 'Intégrée · robuste'}, {k: 'PARTYBOOST', v: 'Multi-enceintes'}],
    shots: [V('audio/src/boombox3.mp4', 1080, 1920, 0.0, 3.0, {cy: 0.45}), V('audio/src/boombox3.mp4', 1080, 1920, 17.6, 20.8, {cy: 0.45}), V('audio/src/boombox3.mp4', 1080, 1920, 22.4, 25.8, {cy: 0.45}), V('audio/src/boombox3.mp4', 1080, 1920, 36.8, 39.6, {cy: 0.45})],
  },
  {
    id: 'partybox310', brand: 'JBL', model: 'PARTYBOX 310', kind: 'ENCEINTE DE FÊTE', price: '330 000', accent: '#3d6bff', photo: 'partybox310.png', cutout: true,
    specs: [{k: 'PUISSANCE', v: '240 W'}, {k: 'LUMIÈRES', v: 'Show lumineux'}, {k: 'AUTONOMIE', v: '18 h'}, {k: 'MOBILITÉ', v: 'Roulettes + poignée'}, {k: 'ENTRÉES', v: 'Micro & guitare'}, {k: 'PROTECTION', v: 'IPX4'}],
    shots: [V('audio/src/partybox310.mp4', 1080, 1920, 0.0, 4.4, {cy: 0.45}), V('audio/src/partybox310.mp4', 1080, 1920, 10.0, 13.5, {cy: 0.45}), V('audio/src/partybox310.mp4', 1080, 1920, 13.5, 17.0, {cy: 0.42})],
  },
  {
    id: 'stage320', brand: 'JBL', model: 'PARTYBOX STAGE 320', kind: 'ENCEINTE DE FÊTE', price: '360 000', accent: '#18e0a0', photo: 'stage320.png', cutout: true, badge: 'PARTY',
    specs: [{k: 'PUISSANCE', v: '240 W'}, {k: 'BATTERIE', v: 'Remplaçable · 18 h'}, {k: 'CONNEXION', v: 'Auracast'}, {k: 'LUMIÈRES', v: 'Show lumineux'}, {k: 'MOBILITÉ', v: 'Roulettes + poignée'}, {k: 'ENTRÉES', v: 'Micros & guitare'}],
    shots: [V('audio/src/stage320.mp4', 720, 1280, 0.0, 3.4, {cy: 0.5}), V('audio/src/stage320.mp4', 720, 1280, 13.6, 16.8, {cy: 0.5}), V('audio/src/stage320.mp4', 720, 1280, 20.6, 24.8, {cy: 0.55})],
  },
  {
    id: 'onyx8', brand: 'HARMAN KARDON', model: 'ONYX STUDIO 8', kind: 'ENCEINTE DE SALON', price: '160 000', accent: '#e8d2a8', photo: 'onyx8.png', cutout: true,
    specs: [{k: 'SON', v: 'Stéréo puissant'}, {k: 'AUTONOMIE', v: '8 h'}, {k: 'MODE STÉRÉO', v: '2 enceintes'}, {k: 'POIGNÉE', v: 'Aluminium'}, {k: 'DESIGN', v: 'Rond iconique'}, {k: 'CONNEXION', v: 'Bluetooth'}],
    shots: [V('audio/src/onyx8.mp4', 720, 1280, 0.0, 3.5, {cy: 0.45}), V('audio/src/onyx8.mp4', 720, 1280, 3.8, 6.3, {cy: 0.45}), V('audio/src/onyx8.mp4', 720, 1280, 6.5, 9.2, {cy: 0.45}), V('audio/src/onyx8.mp4', 720, 1280, 9.2, 12.5, {cy: 0.45})],
  },
  {
    id: 'aura4', brand: 'HARMAN KARDON', model: 'AURA STUDIO 4', kind: 'ENCEINTE DE SALON', price: '170 000', accent: '#5b9dff', photo: 'aura4.jpg', cutout: false, badge: 'NOUVEAU',
    specs: [{k: 'SON', v: '360°'}, {k: 'BASSES', v: 'Caisson intégré'}, {k: 'DESIGN', v: 'Dôme transparent'}, {k: 'LUMIÈRE', v: "Éclairage d'ambiance"}, {k: 'CONNEXION', v: 'Bluetooth + Auracast'}],
    shots: [V('audio/src/aura4.mp4', 360, 640, 0.0, 4.5, {cy: 0.4}), V('audio/src/aura4.mp4', 360, 640, 4.5, 9.6, {cy: 0.4}), V('audio/src/aura4.mp4', 360, 640, 10.0, 12.5, {cy: 0.5})],
  },
  {
    id: 'onyx9', brand: 'HARMAN KARDON', model: 'ONYX STUDIO 9', kind: 'ENCEINTE DE SALON', price: '180 000', accent: '#c9ced6', photo: 'onyx9.png', cutout: true, badge: 'NOUVEAU',
    specs: [{k: 'SON', v: 'Stéréo riche'}, {k: 'CONNEXION', v: 'Bluetooth + Auracast'}, {k: 'AUTONOMIE', v: '8 h'}, {k: 'POIGNÉE', v: 'Aluminium'}, {k: 'DESIGN', v: 'Premium'}],
    shots: [V('audio/src/onyx9.mp4', 1080, 1920, 15.2, 19.0, {cy: 0.55}), V('audio/src/onyx9.mp4', 1080, 1920, 25.0, 29.5, {cy: 0.55}), V('audio/src/onyx9.mp4', 1080, 1920, 41.0, 45.0, {cy: 0.55})],
  },
  {
    id: 'bose', brand: 'BOSE', model: 'QUIETCOMFORT ULTRA', kind: 'CASQUE PREMIUM', price: '260 000', accent: '#d9b26a', photo: 'bose.png', cutout: true, badge: 'PREMIUM',
    specs: [{k: 'ANC', v: 'Réduction de bruit légendaire'}, {k: 'AUDIO', v: 'Immersif spatial'}, {k: 'AUTONOMIE', v: "Jusqu'à 24 h"}, {k: 'MICRO', v: 'Appels clairs'}, {k: 'MODE', v: 'Aware (transparence)'}, {k: 'CONFORT', v: 'Premium'}],
    shots: [P('bose.png', 629, 787, 1.0, 1.1, 0.5, 0.5, 3), V(BO, 720, 1280, 2.9, 4.1, {cy: 0.6}), V(BO, 720, 1280, 4.75, 5.95, {cy: 0.6}), V(BO, 720, 1280, 8.95, 10.1, {cy: 0.6})],
  },
  {
    id: 'homepod', brand: 'APPLE', model: 'HOMEPOD 2', kind: 'ENCEINTE INTELLIGENTE', price: '290 000', accent: '#9ad7ff', photo: 'homepod.png', cutout: true,
    specs: [{k: 'SON', v: 'Haute fidélité'}, {k: 'AUDIO', v: 'Spatial'}, {k: 'ACOUSTIQUE', v: 'Adaptation à la pièce'}, {k: 'ASSISTANT', v: 'Siri'}, {k: 'MAISON', v: 'Domotique connectée'}, {k: 'CAPTEURS', v: 'Température & humidité'}],
    shots: [V(HP, 1080, 1920, 4.5, 8.5, {cy: 0.6}), V(HP, 1080, 1920, 16.5, 22.5, {cy: 0.6}), V(HP, 1080, 1920, 28.6, 33.0, {cy: 0.6})],
  },
];

export const FPS_A = 30;
export const VO_DELAY_A = 10;
export const HERO = 105; // présentation 3D de la photo (images)
export const SCENE_A = 450; // 15 s par produit
export const OVERLAP = 16; // transition « onde » entre deux produits
const sec = (s: number) => Math.round(s * FPS_A);
export const vlenA = (id: keyof typeof VOICE) => sec(VOICE[id]);
export const INTRO_A = 180;
// le prix tombe quand la voix l'annonce (≈ 2,6 s avant la fin de la voix)
export const priceAtA = (p: AP) => Math.min(SCENE_A - sec(2.2), VO_DELAY_A + vlenA(p.id) - sec(2.6));
export const OUTRO_A = vlenA('outro') + VO_DELAY_A + sec(2.6);
export const startA = (i: number) => INTRO_A + i * SCENE_A;
export const TOTAL_A = INTRO_A + PRODUCTS_A.length * SCENE_A + OUTRO_A;
