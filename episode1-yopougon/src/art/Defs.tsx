// Motifs et dégradés partagés (chemise fleurie, treillis, jean, tôle, trame BD…)
export const Defs: React.FC = () => (
  <defs>
    <pattern id="floral" width="40" height="40" patternUnits="userSpaceOnUse">
      <rect width="40" height="40" fill="#1f5e86" />
      <g fill="#e8452c">
        <circle cx="10" cy="10" r="5" /><circle cx="4" cy="8" r="3.5" /><circle cx="15" cy="7" r="3.5" />
        <circle cx="8" cy="15" r="3.5" /><circle cx="14" cy="14" r="3.5" />
      </g>
      <circle cx="10" cy="11" r="2" fill="#ffd23f" />
      <path d="M26 26 q8 -6 12 4 q-8 4 -12 -4z M24 30 q-4 8 6 10 q0 -8 -6 -10z" fill="#3fa34d" />
      <g fill="#ffd23f"><circle cx="32" cy="32" r="3" /><circle cx="28" cy="36" r="2.5" /><circle cx="36" cy="37" r="2.5" /></g>
    </pattern>
    <pattern id="camo" width="60" height="60" patternUnits="userSpaceOnUse">
      <rect width="60" height="60" fill="#3c4430" />
      <path d="M0 10 q15 -10 25 5 q10 10 -5 18 q-15 5 -20 -23z" fill="#262b1e" />
      <path d="M35 30 q15 -8 22 6 q4 14 -14 16 q-12 -4 -8 -22z" fill="#5a5a3c" />
      <path d="M20 40 q8 -4 12 6 q-6 10 -14 2z" fill="#1b1f15" />
      <path d="M40 0 q12 4 8 14 q-10 2 -8 -14z" fill="#262b1e" />
    </pattern>
    <pattern id="denim" width="8" height="8" patternUnits="userSpaceOnUse">
      <rect width="8" height="8" fill="#3a5a8c" />
      <path d="M0 8 L8 0" stroke="#2c4670" strokeWidth="2" />
    </pattern>
    <pattern id="tole" width="22" height="22" patternUnits="userSpaceOnUse">
      <rect width="22" height="22" fill="#5b6066" />
      <rect width="8" height="22" fill="#6f757b" />
      <rect x="8" width="3" height="22" fill="#3d4146" />
    </pattern>
    <pattern id="toleRouille" width="22" height="22" patternUnits="userSpaceOnUse">
      <rect width="22" height="22" fill="#5a4a3e" />
      <rect width="8" height="22" fill="#7a5b44" />
      <rect x="8" width="3" height="22" fill="#3a2e26" />
    </pattern>
    <pattern id="grille" width="26" height="26" patternUnits="userSpaceOnUse">
      <path d="M0 0 L26 26 M26 0 L0 26" stroke="#8a9096" strokeWidth="3" />
    </pattern>
    <pattern id="briques" width="60" height="30" patternUnits="userSpaceOnUse">
      <rect width="60" height="30" fill="#3b3330" />
      <path d="M0 15 H60 M30 0 V15 M0 15 V30 M60 15 V30" stroke="#2a2422" strokeWidth="2" />
    </pattern>
    <pattern id="journal" width="30" height="12" patternUnits="userSpaceOnUse">
      <rect width="30" height="12" fill="#d9d2bf" />
      <path d="M2 3 H26 M2 6 H22 M2 9 H28" stroke="#8d877a" strokeWidth="1.2" />
    </pattern>
    <pattern id="trame" width="10" height="10" patternUnits="userSpaceOnUse">
      <circle cx="5" cy="5" r="2.2" fill="#000" />
    </pattern>
    <pattern id="bitume" width="80" height="80" patternUnits="userSpaceOnUse">
      <rect width="80" height="80" fill="#15171c" />
      <circle cx="12" cy="20" r="1.5" fill="#22252c" /><circle cx="50" cy="60" r="2" fill="#0d0e12" />
      <circle cx="66" cy="14" r="1.2" fill="#262a31" /><circle cx="30" cy="70" r="1.4" fill="#22252c" />
    </pattern>
    <linearGradient id="ciel" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#03040a" />
      <stop offset="0.6" stopColor="#0b1430" />
      <stop offset="1" stopColor="#1d1830" />
    </linearGradient>
    <radialGradient id="lumJaune">
      <stop offset="0" stopColor="#fff3a0" stopOpacity="0.9" />
      <stop offset="0.4" stopColor="#e8d24a" stopOpacity="0.35" />
      <stop offset="1" stopColor="#e8d24a" stopOpacity="0" />
    </radialGradient>
    <radialGradient id="lumRouge">
      <stop offset="0" stopColor="#ff2a3a" stopOpacity="0.8" />
      <stop offset="1" stopColor="#ff2a3a" stopOpacity="0" />
    </radialGradient>
    <radialGradient id="lumBleue">
      <stop offset="0" stopColor="#2a5cff" stopOpacity="0.9" />
      <stop offset="1" stopColor="#2a5cff" stopOpacity="0" />
    </radialGradient>
    <radialGradient id="lumTel">
      <stop offset="0" stopColor="#bfe4ff" stopOpacity="0.9" />
      <stop offset="1" stopColor="#bfe4ff" stopOpacity="0" />
    </radialGradient>
    <radialGradient id="vignette" cx="0.5" cy="0.5" r="0.75">
      <stop offset="0.55" stopColor="#000" stopOpacity="0" />
      <stop offset="1" stopColor="#000" stopOpacity="0.85" />
    </radialGradient>
    <filter id="flou4"><feGaussianBlur stdDeviation="4" /></filter>
    <filter id="flou10"><feGaussianBlur stdDeviation="10" /></filter>
    <filter id="glow"><feGaussianBlur stdDeviation="6" result="b" /><feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge></filter>
  </defs>
);
