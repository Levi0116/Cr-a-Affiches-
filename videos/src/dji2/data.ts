// Vidéo « La flotte DJI » (version 3D) – Zeynab Store
// Voix off : ../../voice-dji2.json (python3 make-voice.py voice-dji2.json public/dji2/voice --force)
import VOICE from '../dji2-voice.json';

export type P2 = {
  id: keyof typeof VOICE;
  model: string; // nom affiché (sans « DJI »)
  price: string;
  accent: string;
  photo: string | null; // public/dji2/photos/… (null = drone 3D)
  cutout: boolean; // photo détourée (PNG) ou photo avec décor (carte)
  badge?: string;
  specs: {k: string; v: string}[]; // données affichées façon HUD
  clips: string[]; // public/dji2/clips/…
  coverY?: number; // bande qui cache des sous-titres incrustés (px)
  hud: {alt: number; spd: number};
};

export const PRODUCTS2: P2[] = [
  {
    id: 'mini4k', model: 'MINI 4K', price: '400 000', accent: '#2ee6c5', photo: 'mini4k.png', cutout: true, badge: 'IDÉAL DÉBUTANT',
    specs: [{k: 'VIDÉO', v: '4K · nacelle 3 axes'}, {k: 'POIDS', v: '< 249 g'}, {k: 'SÉCURITÉ', v: 'Retour auto GPS'}],
    clips: ['mini4k_2.mp4', 'mini4k_1.mp4'], hud: {alt: 32, spd: 8},
  },
  {
    id: 'flip', model: 'FLIP', price: '650 000', accent: '#38d9ff', photo: 'flip.jpg', cutout: false, badge: 'VLOG',
    specs: [{k: 'DESIGN', v: 'Pliable · hélices protégées'}, {k: 'DÉCOLLAGE', v: 'Depuis la paume'}, {k: 'VIDÉO', v: '4K HDR'}],
    clips: ['flip_1.mp4', 'flip_2.mp4'], hud: {alt: 12, spd: 5},
  },
  {
    id: 'mini3pro', model: 'MINI 3 PRO', price: '700 000', accent: '#ffc21a', photo: 'mini3pro.png', cutout: true,
    specs: [{k: 'CAPTEUR', v: '48 MP · 1/1,3"'}, {k: 'VIDÉO', v: '4K HDR'}, {k: 'MODE', v: 'Vertical natif'}],
    clips: ['mini3pro_1.mp4', 'mini3pro_2.mp4'], hud: {alt: 3, spd: 2},
  },
  {
    id: 'air3s', model: 'AIR 3S', price: '870 000', accent: '#c084fc', photo: 'air3s.png', cutout: true,
    specs: [{k: 'CAMÉRAS', v: 'Double · capteur 1"'}, {k: 'CAPTEUR', v: 'LiDAR avant'}, {k: 'AUTONOMIE', v: '45 min de vol'}],
    clips: ['air3s_1.mp4', 'air3s_2.mp4'], hud: {alt: 18, spd: 11},
  },
  {
    id: 'mini4pro', model: 'MINI 4 PRO', price: '900 000', accent: '#4da3ff', photo: 'mini4pro.jpg', cutout: false,
    specs: [{k: 'OBSTACLES', v: 'Détection 360°'}, {k: 'SUIVI', v: 'ActiveTrack 360°'}, {k: 'PORTÉE', v: '20 km'}],
    clips: ['mini4pro_1.mp4', 'mini4pro_2.mp4'], hud: {alt: 6, spd: 14},
  },
  {
    id: 'mini5pro', model: 'MINI 5 PRO', price: '900 000', accent: '#ff4f8b', photo: 'mini5pro.png', cutout: true, badge: 'NOUVEAU',
    specs: [{k: 'CAPTEUR', v: '1 pouce · 50 MP'}, {k: 'VIDÉO', v: '4K à 120 i/s'}, {k: 'NACELLE', v: 'Rotative'}],
    clips: ['mini5pro_1.mp4', 'mini5pro_2.mp4'], hud: {alt: 24, spd: 9},
  },
  {
    id: 'mavic3', model: 'MAVIC 3', price: '950 000', accent: '#ffd23f', photo: 'mavic3.jpg', cutout: false, badge: 'PRO',
    specs: [{k: 'CAMÉRA', v: 'Hasselblad 4/3'}, {k: 'AUTONOMIE', v: '46 min de vol'}, {k: 'PORTÉE', v: '15 km'}],
    clips: ['mavic3_1.mp4', 'mavic3_2.mp4'], hud: {alt: 41, spd: 16},
  },
  {
    id: 'mavic4pro', model: 'MAVIC 4 PRO', price: '2 250 000', accent: '#ffb020', photo: null, cutout: false, badge: 'PREMIUM',
    specs: [{k: 'CAMÉRAS', v: 'Triple Hasselblad'}, {k: 'VIDÉO', v: '6K HDR'}, {k: 'NACELLE', v: 'Rotation 360°'}],
    clips: ['mavic4pro_1.mp4', 'mavic4pro_2.mp4'], coverY: 1040, hud: {alt: 120, spd: 21},
  },
];

export const FPS2 = 30;
export const VO_DELAY = 9;
export const PHOTO = 75; // durée de la présentation photo 3D (images)
const sec = (s: number) => Math.round(s * FPS2);
export const vlen = (id: keyof typeof VOICE) => sec(VOICE[id]);
export const INTRO2 = 165;
export const sceneLen2 = (p: P2) => Math.max(PHOTO + sec(4), vlen(p.id) + VO_DELAY + sec(0.7));
export const OUTRO2 = vlen('outro') + VO_DELAY + sec(2.2);
export const TOTAL2 = INTRO2 + PRODUCTS2.reduce((a, p) => a + sceneLen2(p), 0) + OUTRO2;
