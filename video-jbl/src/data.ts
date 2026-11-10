// Contenu de la vidéo. Pour ajouter les prix plus tard, remplis `price`
// (ex. '85.000') : la pastille « Prix bientôt » affichera le prix en FCFA.

export type Segment = {src: string; from: number; to: number; speed?: number};

export type Product = {
  id: string;
  name: string;
  model: string;
  tagline: string;
  color: string;
  color2: string;
  price: string;
  specs: {icon: string; title: string; text: string}[];
  segments: Segment[];
};

export const SHOP = {
  name: 'ZEYNAB STORE',
  tag: 'VOTRE SATISFACTION, NOTRE PRIORITÉ',
  contact: '07 04 08 31 66',
  siege: 'Abidjan, Treichville',
  annexes: ['Cocody Saint-Jean', 'Riviera 2', 'Yopougon', 'Bouaké Houphouët-Ville'],
  services: ['Toutes marques de téléphones', 'Vente en gros et détail', 'Livraison disponible'],
};

export const PRODUCTS: Product[] = [
  {
    id: 'xtreme3',
    name: 'JBL',
    model: 'XTREME 3',
    tagline: 'La puissance qui fait vibrer la fête',
    color: '#1f6bff',
    color2: '#0a1f5c',
    price: '',
    specs: [
      {icon: '🔊', title: 'Son JBL Pro', text: 'Basses profondes, 2 radiateurs passifs'},
      {icon: '💧', title: 'Étanche IP67', text: "Résiste à l'eau et à la poussière"},
      {icon: '🔋', title: '15 h d’autonomie', text: 'Fonction powerbank pour ton téléphone'},
      {icon: '🎒', title: 'Bandoulière incluse', text: 'PartyBoost : relie plusieurs enceintes'},
    ],
    segments: [
      {src: 'xtreme3.mp4', from: 0.3, to: 7.0},
      {src: 'xtreme3.mp4', from: 8.0, to: 12.3},
    ],
  },
  {
    id: 'pulse5',
    name: 'JBL',
    model: 'PULSE 5',
    tagline: 'Le son que tu peux voir',
    color: '#c43cff',
    color2: '#3a0a5c',
    price: '',
    specs: [
      {icon: '🌈', title: 'Show lumineux 360°', text: 'Lumières synchronisées avec la musique'},
      {icon: '🔊', title: 'Son 360° – 40 W', text: 'Woofer + tweeter, basses puissantes'},
      {icon: '💧', title: 'Étanche IP67', text: 'Piscine, plage, soirée : aucun souci'},
      {icon: '🔋', title: '12 h d’autonomie', text: 'Bluetooth 5.3 + appli JBL Portable'},
    ],
    segments: [
      {src: 'pulse5-front.mp4', from: 0.2, to: 5.0},
      {src: 'pulse5-back.mp4', from: 3.9, to: 7.9},
      {src: 'pulse5-back.mp4', from: 9.5, to: 11.7},
    ],
  },
  {
    id: 'charge6',
    name: 'JBL',
    model: 'CHARGE 6',
    tagline: 'L’endurance au service du son',
    color: '#ff6a00',
    color2: '#5c1f00',
    price: '',
    specs: [
      {icon: '🔋', title: 'Jusqu’à 28 h', text: '24 h + 4 h avec Playtime Boost'},
      {icon: '🛡️', title: 'IP68 + anti-chute', text: 'Étanche, résiste à la poussière et aux chocs'},
      {icon: '🤖', title: 'AI Sound Boost', text: 'Son optimisé en temps réel'},
      {icon: '⚡', title: 'Powerbank USB-C', text: 'Auracast + sangle amovible'},
    ],
    segments: [
      {src: 'charge6-flip7.mp4', from: 0.0, to: 2.2, speed: 0.6},
      {src: 'charge6-flip7.mp4', from: 4.2, to: 6.4, speed: 0.6},
      {src: 'charge6-flip7.mp4', from: 7.0, to: 9.2, speed: 0.6},
    ],
  },
  {
    id: 'flip7',
    name: 'JBL',
    model: 'FLIP 7',
    tagline: 'Compacte, puissante, partout avec toi',
    color: '#ff2a4d',
    color2: '#5c0016',
    price: '',
    specs: [
      {icon: '🔊', title: 'Son JBL Pro', text: 'AI Sound Boost, basses renforcées'},
      {icon: '🛡️', title: 'IP68 + anti-chute', text: 'Étanche et ultra résistante'},
      {icon: '🔋', title: 'Jusqu’à 16 h', text: '14 h + 2 h avec Playtime Boost'},
      {icon: '🔗', title: 'Mousqueton amovible', text: 'Auracast + audio par USB-C'},
    ],
    segments: [
      {src: 'charge6-flip7.mp4', from: 2.0, to: 4.0, speed: 0.5},
      {src: 'charge6-flip7.mp4', from: 9.6, to: 11.0, speed: 0.5},
      {src: 'charge6-flip7.mp4', from: 12.6, to: 14.7, speed: 0.5},
    ],
  },
];

export const FPS = 30;
export const INTRO = 120;
export const SCENE = 330;
export const OUTRO = 270;
export const TOTAL = INTRO + PRODUCTS.length * SCENE + OUTRO;
