// Vidéo « Drones DJI & caméra Xiaomi » – Zeynab Store
// Les prix et les textes sont modifiables ici. La voix off est dans ../voice-dji.json
// (régénérer avec : python3 make-voice.py voice-dji.json public/dji/voice --force).
import VOICE from './dji-voice.json';

export type DSeg = {from: number; to: number; focus?: number; y?: number; zoom?: number; rotate?: number};
export type Drone = {
  id: keyof typeof VOICE;
  brand: string;
  model: string;
  badge?: string;
  price: string; // vide = « Prix sur demande »
  accent: string;
  specs: {icon: string; title: string; text: string}[];
  segments: DSeg[];
};

export const DRONES: Drone[] = [
  {
    id: 'mavic4pro', brand: 'DJI', model: 'MAVIC 4 PRO', badge: 'PREMIUM', price: '2 250 000', accent: '#ffb020',
    specs: [
      {icon: '📸', title: 'Triple caméra Hasselblad', text: 'Capteur principal 4/3 de 100 MP'},
      {icon: '🎬', title: 'Vidéo 6K HDR', text: 'Images dignes du cinéma'},
      {icon: '🔄', title: 'Nacelle 360°', text: 'Rotation complète « Infinity Gimbal »'},
      {icon: '🛰️', title: '51 min de vol', text: 'Transmission longue portée O4+'},
    ],
    segments: [{from: 0.0, to: 6.6, focus: 55}, {from: 43.0, to: 47.9, focus: 55}],
  },
  {
    id: 'flip', brand: 'DJI', model: 'FLIP', badge: 'VLOG', price: '', accent: '#38d9ff',
    specs: [
      {icon: '🪶', title: 'Moins de 249 g', text: 'Pliable, se glisse dans un sac'},
      {icon: '🛡️', title: 'Hélices protégées', text: 'Vol sûr, même près des gens'},
      {icon: '🎥', title: 'Vidéo 4K HDR', text: 'Capteur 1/1,3 pouce'},
      {icon: '✋', title: 'Décollage paume', text: 'Suivi intelligent du sujet'},
    ],
    segments: [{from: 7.5, to: 10.6, focus: 62, y: 40, zoom: 1.1}],
  },
  {
    id: 'c300', brand: 'XIAOMI', model: 'SMART CAMERA C300', badge: 'SÉCURITÉ', price: '45 000', accent: '#ff7a1a',
    specs: [
      {icon: '📹', title: 'Vidéo 2K', text: 'Image nette jour et nuit'},
      {icon: '🔄', title: 'Rotation 360°', text: 'Vue panoramique de la pièce'},
      {icon: '🌙', title: 'Vision de nuit', text: 'Infrarouge, même dans le noir'},
      {icon: '📱', title: 'Détection IA + audio', text: 'Alertes sur ton téléphone'},
    ],
    segments: [{from: 11.3, to: 12.5, focus: 30}],
  },
  {
    id: 'mini3pro', brand: 'DJI', model: 'MINI 3 PRO', price: '700 000', accent: '#7cf29c',
    specs: [
      {icon: '🪶', title: 'Moins de 249 g', text: 'Léger et facile à transporter'},
      {icon: '🎥', title: 'Vidéo 4K HDR', text: 'Capteur 48 MP de 1/1,3 pouce'},
      {icon: '📲', title: 'Prise de vue verticale', text: 'Parfait pour TikTok et Reels'},
      {icon: '🛡️', title: 'Détection d’obstacles', text: 'Dans trois directions'},
    ],
    segments: [{from: 13.0, to: 15.2, focus: 45}, {from: 16.0, to: 17.8, focus: 48}],
  },
  {
    id: 'mini4pro', brand: 'DJI', model: 'MINI 4 PRO', price: '900 000', accent: '#4da3ff',
    specs: [
      {icon: '🛡️', title: 'Détection 360°', text: 'Évite les obstacles dans toutes les directions'},
      {icon: '🎯', title: 'Suivi ActiveTrack 360°', text: 'Il te suit tout seul'},
      {icon: '📡', title: 'Portée 20 km', text: 'Transmission vidéo O4'},
      {icon: '🎥', title: 'Vidéo 4K HDR', text: 'Ralenti 4K à 100 i/s'},
    ],
    segments: [{from: 18.5, to: 22.8, focus: 45}],
  },
  {
    id: 'air3s', brand: 'DJI', model: 'AIR 3S', price: '870 000', accent: '#c084fc',
    specs: [
      {icon: '📸', title: 'Double caméra', text: 'Grand capteur 1 pouce + téléobjectif'},
      {icon: '🔦', title: 'Capteur LiDAR', text: 'Vol sécurisé, même de nuit'},
      {icon: '⏱️', title: '45 min de vol', text: 'Transmission 20 km'},
      {icon: '🎥', title: 'Vidéo 4K HDR', text: 'Mode nuit amélioré'},
    ],
    segments: [{from: 23.0, to: 25.9, focus: 50}],
  },
  {
    id: 'mini4k', brand: 'DJI', model: 'MINI 4K', badge: 'IDÉAL DÉBUTANT', price: '400 000', accent: '#2ee6c5',
    specs: [
      {icon: '🎥', title: 'Vidéo 4K', text: 'Nacelle stabilisée 3 axes'},
      {icon: '🪶', title: 'Moins de 249 g', text: 'Simple à piloter'},
      {icon: '🏠', title: 'Retour automatique', text: 'Revient seul grâce au GPS'},
      {icon: '⏱️', title: '31 min de vol', text: 'Résiste au vent'},
    ],
    segments: [{from: 26.0, to: 30.3, focus: 50}],
  },
  {
    id: 'mini5pro', brand: 'DJI', model: 'MINI 5 PRO', badge: 'NOUVEAU', price: '900 000', accent: '#ff4f8b',
    specs: [
      {icon: '📸', title: 'Capteur 1 pouce', text: '50 MP, photos très détaillées'},
      {icon: '🎬', title: '4K à 120 i/s', text: 'Ralentis ultra fluides'},
      {icon: '🛡️', title: 'Détection 360°', text: 'Obstacles évités automatiquement'},
      {icon: '🪶', title: 'Drone de poche', text: 'Compact et pliable'},
    ],
    segments: [{from: 31.5, to: 34.4, focus: 50, rotate: 180}],
  },
  {
    id: 'mavic3', brand: 'DJI', model: 'MAVIC 3', badge: 'PRO', price: '950 000', accent: '#ffd23f',
    specs: [
      {icon: '📸', title: 'Caméra Hasselblad 4/3', text: 'Couleurs naturelles et précises'},
      {icon: '🎬', title: 'Vidéo 5,1K', text: 'Qualité professionnelle'},
      {icon: '⏱️', title: '46 min de vol', text: 'Transmission 15 km'},
      {icon: '🛡️', title: 'Détection 360°', text: 'Vol sûr dans toutes les directions'},
    ],
    segments: [{from: 35.2, to: 42.8, focus: 45}],
  },
];

export const D_FPS = 30;
export const VOICE_DELAY = 15; // la voix démarre 0,5 s après le début de la scène
const sec = (s: number) => Math.round(s * D_FPS);
export const voiceLen = (id: keyof typeof VOICE) => sec(VOICE[id]);
export const D_INTRO = Math.max(sec(4), voiceLen('intro') + VOICE_DELAY + sec(0.6));
export const sceneLen = (d: Drone) => voiceLen(d.id) + VOICE_DELAY + sec(0.9);
export const D_OUTRO = voiceLen('outro') + VOICE_DELAY + sec(2.5);
export const D_TOTAL = D_INTRO + DRONES.reduce((a, d) => a + sceneLen(d), 0) + D_OUTRO;
