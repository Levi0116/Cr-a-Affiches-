// Vidéo « Harman Kardon » – Zeynab Store
// Voix off : ../voice-hk.json (python3 make-voice.py voice-hk.json public/hk/voice --force)
import VOICE from './hk-voice.json';

export type HSeg = {
  src: string; // fichier dans public/hk (vidéo .mp4 ou photo .jpg)
  from?: number; to?: number; // passage de la vidéo (secondes)
  focus?: number; y?: number; // point de cadrage (%)
  zoom?: [number, number]; // zoom début → fin (photo) ou fixe (vidéo : premier nombre)
  hold?: number; // durée d'affichage d'une photo (secondes)
};
export type HK = {
  id: keyof typeof VOICE;
  model: string;
  badge?: string;
  price: string;
  accent: string;
  specs: {icon: string; title: string; text: string}[];
  segments: HSeg[];
};

export const HKS: HK[] = [
  {
    id: 'onyx9', model: 'ONYX STUDIO 9', badge: 'NOUVEAU', price: '180 000', accent: '#d9dde3',
    specs: [
      {icon: '🔊', title: 'Son stéréo riche', text: 'Puissant, clair, basses profondes'},
      {icon: '🔋', title: 'Jusqu’à 8 h', text: 'Batterie rechargeable intégrée'},
      {icon: '📶', title: 'Bluetooth + Auracast', text: 'Relie plusieurs enceintes'},
      {icon: '✨', title: 'Poignée aluminium', text: 'Design premium et élégant'},
    ],
    segments: [{src: 'onyx9.mp4', from: 0.0, to: 8.3, focus: 42}, {src: 'onyx9.mp4', from: 9.8, to: 12.0, focus: 55}],
  },
  {
    id: 'onyx8', model: 'ONYX STUDIO 8', badge: 'ICONIQUE', price: '160 000', accent: '#8fb3d9',
    specs: [
      {icon: '🔊', title: 'Son stéréo puissant', text: 'La signature Harman Kardon'},
      {icon: '🔋', title: '8 h d’autonomie', text: 'Musique toute la soirée'},
      {icon: '🔗', title: 'Mode stéréo', text: 'Connecte 2 enceintes ensemble'},
      {icon: '✨', title: 'Poignée aluminium', text: 'Design rond iconique'},
    ],
    segments: [
      {src: 'onyx8.jpg', focus: 55, y: 50, zoom: [1.0, 1.15], hold: 4},
      {src: 'onyx8.jpg', focus: 18, y: 75, zoom: [1.5, 1.7], hold: 4},
      {src: 'onyx8.jpg', focus: 55, y: 50, zoom: [1.35, 1.2], hold: 4},
    ],
  },
  {
    id: 'aura2', model: 'AURA STUDIO 2', price: '170 000', accent: '#5b9dff',
    specs: [
      {icon: '🌐', title: 'Son 360°', text: 'Remplit toute la pièce'},
      {icon: '💡', title: 'Éclairage d’ambiance', text: 'Lumière douce et envoûtante'},
      {icon: '🔮', title: 'Dôme transparent', text: 'Design qui attire tous les regards'},
      {icon: '🎵', title: 'Basses profondes', text: 'Caisson de basse intégré, Bluetooth'},
    ],
    segments: [
      {src: 'aura2.mp4', from: 0.0, to: 3.8, y: 45},
      {src: 'aura2.mp4', from: 6.5, to: 10.5, y: 55},
      {src: 'aura2.mp4', from: 12.0, to: 14.5, y: 50},
    ],
  },
  {
    id: 'aura3', model: 'AURA STUDIO 3', badge: 'STAR DU SALON', price: '175 000', accent: '#e8c46a',
    specs: [
      {icon: '⚡', title: '100 W de puissance', text: 'Un son qui fait vibrer la maison'},
      {icon: '🌐', title: 'Son 360°', text: 'Six tweeters + caisson de basse'},
      {icon: '💡', title: 'Lumière d’ambiance', text: 'Effets lumineux spectaculaires'},
      {icon: '🔮', title: 'Design transparent', text: 'L’icône Harman Kardon'},
    ],
    segments: [
      {src: 'aura3.mp4', from: 0.0, to: 5.0, y: 45},
      {src: 'aura3.mp4', from: 12.6, to: 16.7, y: 45},
    ],
  },
];

export const H_FPS = 30;
export const H_VOICE_DELAY = 15;
const sec = (s: number) => Math.round(s * H_FPS);
export const hVoiceLen = (id: keyof typeof VOICE) => sec(VOICE[id]);
export const H_INTRO = hVoiceLen('intro') + H_VOICE_DELAY + sec(0.6);
export const hSceneLen = (d: HK) => hVoiceLen(d.id) + H_VOICE_DELAY + sec(1.0);
export const H_OUTRO = hVoiceLen('outro') + H_VOICE_DELAY + sec(2.5);
export const H_TOTAL = H_INTRO + HKS.reduce((a, d) => a + hSceneLen(d), 0) + H_OUTRO;
