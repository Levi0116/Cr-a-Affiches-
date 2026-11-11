import React from "react";
import { noise, rnd } from "../lib/anim";

// Décor de la rue de Yopougon, 01h30. Monde de 1920×1080 unités.
export const NEAR = 965; // sol du trottoir côté dépôt
export const FAR = 745; // sol du trottoir d'en face
const OUT = "#0b0a10";

export const Ciel: React.FC<{ frame: number }> = ({ frame }) => (
  <g>
    <rect x={-400} y={-200} width={2720} height={1000} fill="url(#ciel)" />
    {Array.from({ length: 40 }).map((_, i) => (
      <circle key={i} cx={rnd(i) * 2400 - 200} cy={rnd(i + 99) * 300 - 100} r={rnd(i + 7) * 1.6 + 0.4} fill="#cfd8ff" opacity={0.25 + 0.4 * Math.abs(noise(frame / 20, i))} />
    ))}
    {/* silhouettes lointaines (immeubles de Yop, château d'eau) */}
    <path d="M-400 520 L-400 300 h120 v-40 h90 v80 h140 v-120 h70 v120 h160 v-60 h110 v90 h130 v-150 h40 v-30 h30 v30 h40 v150 h160 v-70 h120 v100 h90 v-130 h150 v130 h130 v-60 h200 v80 h160 v-110 h120 v110 h220 v220z" fill="#080b18" />
    <g fill="#080b18">
      <rect x={1560} y={230} width={14} height={160} />
      <path d="M1520 230 h94 l-10 -50 h-74z" />
    </g>
    {Array.from({ length: 34 }).map((_, i) => {
      const on = rnd(i + 300) > 0.45;
      return on ? <rect key={i} x={rnd(i + 200) * 2300 - 300} y={260 + rnd(i + 250) * 220} width={9} height={12} fill={rnd(i) > 0.7 ? "#ffb347" : "#e8d27a"} opacity={0.35} /> : null;
    })}
    {/* brume orangée de la ville */}
    <rect x={-400} y={420} width={2720} height={200} fill="#ff7a3a" opacity={0.05} />
  </g>
);

// côté d'en face : façades, maquis "Chez Chimène", poteau électrique
export const FaceOpposee: React.FC<{ frame: number; maquisOn?: number }> = ({ frame, maquisOn = 1 }) => {
  const fl = 0.85 + 0.15 * noise(frame / 3, 4);
  return (
    <g>
      {/* maisons à gauche */}
      <rect x={-400} y={430} width={1650} height={FAR - 430} fill="url(#briques)" />
      <rect x={-400} y={415} width={1650} height={22} fill="#26201d" />
      <path d="M-400 415 L-380 360 H1230 L1250 415Z" fill="url(#toleRouille)" stroke={OUT} strokeWidth={3} />
      {[60, 380, 900].map((x, i) => (
        <g key={i}>
          <rect x={x} y={520} width={150} height={FAR - 520} fill="#1a1513" stroke={OUT} strokeWidth={3} />
          <path d={`M${x} 520 v${FAR - 520} M${x + 50} 520 v${FAR - 520} M${x + 100} 520 v${FAR - 520}`} stroke="#2b2420" strokeWidth={4} />
        </g>
      ))}
      <text x={130} y={500} fill="#6b5a4a" fontSize={22} fontFamily="Arial Black" opacity={0.6}>COIFFURE</text>
      <text x={430} y={500} fill="#6b5a4a" fontSize={22} fontFamily="Arial Black" opacity={0.6}>CABINE</text>
      {/* maquis */}
      <rect x={1250} y={400} width={1100} height={FAR - 400} fill="#2a1416" />
      <path d="M1230 400 L1260 340 H2350 V400Z" fill="url(#tole)" stroke={OUT} strokeWidth={3} />
      <rect x={1300} y={470} width={700} height={FAR - 470} fill="#4a0a12" />
      <rect x={1300} y={470} width={700} height={FAR - 470} fill="#ff2a3a" opacity={0.22 * fl * maquisOn} />
      {/* comptoir et bouteilles */}
      <rect x={1340} y={600} width={420} height={70} fill="#2a0d10" stroke={OUT} strokeWidth={3} />
      {Array.from({ length: 16 }).map((_, i) => (
        <rect key={i} x={1360 + i * 24} y={510} width={10} height={34} rx={3} fill={i % 3 ? "#2e5d2a" : "#6b3a12"} opacity={0.8} />
      ))}
      <rect x={1350} y={545} width={400} height={6} fill="#1a0608" />
      {/* enseigne néon */}
      <g filter="url(#glow)" opacity={maquisOn * (frame % 97 < 3 ? 0.4 : 1)}>
        <rect x={1360} y={410} width={520} height={50} rx={8} fill="#140406" stroke="#ff2a3a" strokeWidth={3} />
        <text x={1620} y={446} textAnchor="middle" fill="#ff4d5a" fontSize={30} fontWeight={900} fontFamily="Arial Black, Arial" letterSpacing={3}>
          MAQUIS CHEZ CHIMÈNE
        </text>
      </g>
      {/* guirlande */}
      <path d="M1250 470 Q1500 500 1750 470 Q1950 500 2100 470" stroke="#111" strokeWidth={2} fill="none" />
      {Array.from({ length: 14 }).map((_, i) => {
        const x = 1270 + i * 60;
        const yy = 476 + Math.sin((i / 13) * Math.PI * 2) * 10 + 8;
        const on = (Math.floor(frame / 12) + i) % 3 !== 0;
        return <circle key={i} cx={x} cy={yy} r={5} fill={i % 2 ? "#ff3b3b" : "#ffd23f"} opacity={on ? 0.95 * maquisOn : 0.25} />;
      })}
      {/* chaises et tables en plastique */}
      {[1400, 1700, 1880].map((x, i) => (
        <g key={i} opacity={0.95}>
          <rect x={x} y={FAR - 62} width={70} height={8} fill="#d9d4c7" stroke={OUT} strokeWidth={2} />
          <path d={`M${x + 6} ${FAR - 54} l-6 54 M${x + 64} ${FAR - 54} l6 54`} stroke="#d9d4c7" strokeWidth={5} />
          <path d={`M${x - 40} ${FAR - 40} h30 v-40 h-30z M${x - 40} ${FAR - 40} v40 M${x - 10} ${FAR - 40} v40`} fill="none" stroke="#b53a30" strokeWidth={5} />
          <rect x={x + 20} y={FAR - 86} width={9} height={24} rx={3} fill="#2e5d2a" />
        </g>
      ))}
    </g>
  );
};

export const Poteau: React.FC = () => (
  <g>
    <rect x={1168} y={120} width={22} height={FAR - 120 + 6} fill="#4a3f36" stroke={OUT} strokeWidth={3} />
    <rect x={1120} y={160} width={120} height={14} fill="#3a322c" stroke={OUT} strokeWidth={3} />
    <rect x={1150} y={250} width={58} height={70} rx={6} fill="#5a6168" stroke={OUT} strokeWidth={3} />
    <path d="M-400 175 Q400 260 1125 166 M1235 166 Q1700 250 2400 175 M-400 210 Q500 300 1140 172 M1220 172 Q1800 290 2400 215" stroke="#07080c" strokeWidth={3} fill="none" />
    <path d="M1170 400 h18 M1170 520 h18" stroke="#2c241f" strokeWidth={3} />
    <rect x={1150} y={430} width={56} height={34} fill="#d9d4c7" opacity={0.6} />
    <text x={1178} y={452} textAnchor="middle" fontSize={11} fill="#333" fontFamily="Arial">PRIÈRE</text>
  </g>
);

export const Camion: React.FC<{ frame: number }> = () => (
  <g>
    <rect x={560} y={600} width={150} height={120} rx={14} fill="#c9c2a8" stroke={OUT} strokeWidth={3.5} />
    <path d="M572 612 h90 v50 h-90z" fill="#1f2a38" stroke={OUT} strokeWidth={3} />
    <rect x={700} y={470} width={390} height={250} fill="#b8b29a" stroke={OUT} strokeWidth={3.5} />
    <rect x={700} y={470} width={390} height={250} fill="#000" opacity={0.25} />
    <text x={895} y={590} textAnchor="middle" fill="#2a4a7a" fontSize={44} fontWeight={900} fontFamily="Arial Black, Arial" opacity={0.75}>
      BOISSONS
    </text>
    <text x={895} y={630} textAnchor="middle" fill="#7a2a2a" fontSize={20} fontWeight={900} fontFamily="Arial" opacity={0.7}>
      LIVRAISON YOP • ABOBO • KOUMASSI
    </text>
    <rect x={560} y={712} width={540} height={18} fill="#2a2a2a" stroke={OUT} strokeWidth={3} />
    {[630, 790, 1010].map((x) => (
      <g key={x}>
        <circle cx={x} cy={735} r={30} fill="#111" stroke={OUT} strokeWidth={3} />
        <circle cx={x} cy={735} r={12} fill="#555" />
      </g>
    ))}
  </g>
);

export const Route: React.FC<{ frame: number; gyro: number; flash: number }> = ({ gyro, flash }) => (
  <g>
    <rect x={-400} y={FAR} width={2720} height={NEAR - FAR + 200} fill="url(#bitume)" />
    <rect x={-400} y={FAR} width={2720} height={10} fill="#3a3a40" />
    {Array.from({ length: 14 }).map((_, i) => (
      <rect key={i} x={-380 + i * 200} y={850} width={110} height={7} fill="#8a8a7a" opacity={0.35} />
    ))}
    {/* flaque qui reflète */}
    <ellipse cx={1050} cy={880} rx={160} ry={22} fill="#1d2435" />
    <ellipse cx={1050} cy={880} rx={140} ry={16} fill="#ff2a3a" opacity={0.12} />
    {gyro > 0 && <ellipse cx={1050} cy={880} rx={140} ry={16} fill={flash ? "#ff2a3a" : "#2a5cff"} opacity={0.5 * gyro} />}
    <path d="M300 900 q30 -6 50 4 q-20 10 -50 -4z M1600 820 q40 -6 60 6 q-30 8 -60 -6z" fill="#0a0b0e" />
  </g>
);

// Dépôt ("ghetto") côté proche
export const DepotFond: React.FC<{ frame: number; neon: number; tv: "clip" | "flash" | "off" }> = ({ frame, neon, tv }) => (
  <g>
    <rect x={-400} y={330} width={1140} height={NEAR - 330} fill="#2b2622" />
    <rect x={-400} y={330} width={1140} height={NEAR - 330} fill="#000" opacity={0.25} />
    {/* étagères */}
    {[480, 580, 680].map((yy) => (
      <g key={yy}>
        <rect x={20} y={yy} width={520} height={10} fill="#4a3a2a" stroke={OUT} strokeWidth={2.5} />
        {Array.from({ length: 19 }).map((_, i) => (
          <g key={i}>
            <rect x={34 + i * 27} y={yy - 46} width={14} height={46} rx={4} fill={(i + yy) % 4 === 0 ? "#6b3a12" : (i + yy) % 5 === 0 ? "#c9c2a8" : "#2e5d2a"} stroke={OUT} strokeWidth={1.5} />
            <rect x={38 + i * 27} y={yy - 30} width={6} height={12} fill="#e8d27a" opacity={0.6} />
          </g>
        ))}
      </g>
    ))}
    {/* frigo */}
    <rect x={-200} y={470} width={190} height={NEAR - 480} rx={10} fill="#a82020" stroke={OUT} strokeWidth={3} />
    <rect x={-185} y={500} width={160} height={260} rx={6} fill="#5c1010" stroke={OUT} strokeWidth={2} />
    <rect x={-185} y={500} width={160} height={260} rx={6} fill="#bfe4ff" opacity={0.12} />
    <text x={-105} y={810} textAnchor="middle" fill="#fff" fontSize={26} fontWeight={900} fontFamily="Arial Black">FRAIS</text>
    {/* télé */}
    <Tele x={590} y={420} frame={frame} state={tv} />
    {/* tôle et néon */}
    <path d="M-420 330 L-400 280 H760 L790 335 Z" fill="url(#tole)" stroke={OUT} strokeWidth={3.5} />
    <rect x={-400} y={330} width={1160} height={16} fill="#1a1715" />
    <text x={240} y={318} textAnchor="middle" fill="#e8d27a" fontSize={26} fontWeight={900} fontFamily="Arial Black, Arial" opacity={0.85} letterSpacing={2}>
      DÉPÔT • CASIERS 66 CL
    </text>
    <rect x={130} y={360} width={420} height={12} rx={6} fill="#fffbd0" opacity={0.25 + 0.75 * neon} filter="url(#glow)" />
    <rect x={124} y={356} width={10} height={20} fill="#444" />
    <rect x={546} y={356} width={10} height={20} fill="#444" />
  </g>
);

export const Tele: React.FC<{ x: number; y: number; frame: number; state: "clip" | "flash" | "off"; big?: boolean }> = ({ x, y, frame, state }) => (
  <g transform={`translate(${x} ${y})`}>
    <rect x={0} y={0} width={120} height={90} rx={10} fill="#222" stroke={OUT} strokeWidth={3} />
    <rect x={8} y={8} width={104} height={74} rx={6} fill={state === "flash" ? "#1a0a0a" : "#1c2a4a"} />
    {state === "clip" && (
      <g>
        <rect x={8} y={8} width={104} height={74} rx={6} fill={["#7b2ff7", "#f72fa0", "#2ff7c8", "#f7b72f"][Math.floor(frame / 8) % 4]} opacity={0.6} />
        <circle cx={60 + Math.sin(frame / 5) * 20} cy={46} r={14} fill="#111" opacity={0.6} />
      </g>
    )}
    {state === "flash" && (
      <g>
        <rect x={8} y={58} width={104} height={18} fill="#d50000" />
        <rect x={8} y={20} width={104} height={30} fill="#333" opacity={0.6} />
        <text x={11} y={70} fontSize={7.5} fontWeight={900} fill="#fff" fontFamily="Arial">BRAQUAGE ANGRÉ 8è TR.</text>
        <text x={12} y={30} fontSize={6} fontWeight={900} fill="#ff5252" fontFamily="Arial">FLASH INFO</text>
      </g>
    )}
    <path d="M40 0 l-14 -24 M80 0 l14 -24" stroke="#222" strokeWidth={3} />
  </g>
);

// pile de casiers de bière
export const Casiers: React.FC<{ x: number; y: number; rows?: number; cols?: number; shake?: number }> = ({ x, y, rows = 4, cols = 3, shake = 0 }) => (
  <g transform={`translate(${x + shake} ${y})`}>
    {Array.from({ length: rows }).map((_, r) =>
      Array.from({ length: cols - (r === rows - 1 ? 1 : 0) }).map((__, c) => {
        const cx = c * 68 + (r === rows - 1 ? 34 : 0) + (r % 2) * 4;
        const cy = -(r + 1) * 46;
        const col = (r + c) % 3 === 0 ? "#c62828" : (r + c) % 3 === 1 ? "#f2b81f" : "#1e6b34";
        return (
          <g key={`${r}-${c}`}>
            <rect x={cx} y={cy} width={66} height={46} rx={4} fill={col} stroke={OUT} strokeWidth={3} />
            <rect x={cx + 8} y={cy + 10} width={50} height={12} rx={4} fill="#000" opacity={0.35} />
            {[0, 1, 2, 3].map((k) => (
              <rect key={k} x={cx + 9 + k * 13} y={cy - 12} width={8} height={14} rx={3} fill="#3a2a10" stroke={OUT} strokeWidth={1.2} />
            ))}
          </g>
        );
      }),
    )}
  </g>
);

// casier retourné servant de siège
export const Siege: React.FC<{ x: number }> = ({ x }) => (
  <g>
    <rect x={x - 38} y={NEAR - 108} width={76} height={108} rx={5} fill="#c62828" stroke={OUT} strokeWidth={3} />
    <path d={`M${x - 30} ${NEAR - 90} h60 M${x - 30} ${NEAR - 60} h60 M${x - 30} ${NEAR - 30} h60`} stroke="#7a1414" strokeWidth={5} />
    <rect x={x - 70} y={NEAR - 40} width={40} height={36} fill="url(#journal)" stroke={OUT} strokeWidth={2} transform={`rotate(-8 ${x - 50} ${NEAR - 20})`} />
  </g>
);

// grille du ghetto (accordéon) — open 0 = presque fermée
export const Grille: React.FC<{ open: number; shake: number }> = ({ open, shake }) => {
  const w = 150 - open * 105;
  return (
    <g transform={`translate(${shake} 0)`}>
      <rect x={742 - w} y={350} width={w} height={NEAR - 350} fill="url(#grille)" stroke="#5a6066" strokeWidth={6} />
      <rect x={736} y={340} width={12} height={NEAR - 330} fill="#3a3f45" stroke={OUT} strokeWidth={3} />
      <rect x={742 - w - 6} y={350} width={12} height={NEAR - 350} fill="#6f757b" stroke={OUT} strokeWidth={3} />
    </g>
  );
};

export const Trottoir: React.FC = () => (
  <g>
    <rect x={-400} y={NEAR - 8} width={2720} height={300} fill="#24211f" />
    <rect x={-400} y={NEAR - 8} width={2720} height={10} fill="#3d3833" />
    <path d="M760 1010 l40 -6 l30 10 M1300 1040 l60 -8" stroke="#141210" strokeWidth={3} />
  </g>
);

// Pick-up noir sans plaque
export const PickUp: React.FC<{ x: number; frame: number; gyro: number; bounce?: number }> = ({ x, frame, gyro, bounce = 0 }) => {
  const ph = Math.floor(frame / 5) % 2;
  return (
    <g transform={`translate(${x} ${bounce})`}>
      <ellipse cx={0} cy={950} rx={330} ry={18} fill="#000" opacity={0.6} />
      <path d="M-310 900 v-110 q0 -14 14 -16 l120 -10 l60 -84 q8 -10 22 -10 h170 q14 0 18 14 l20 80 h170 q22 0 24 22 v114z" fill="#0d0e11" stroke="#000" strokeWidth={4} />
      <path d="M-160 770 l50 -70 h150 l16 70z" fill="#1c2638" stroke="#000" strokeWidth={3} />
      <path d="M-150 765 l40 -56 h40 l-30 56z" fill="#3a4a66" opacity={0.5} />
      <path d="M-300 815 h600" stroke="#2a2c33" strokeWidth={3} />
      <rect x={-312} y={862} width={40} height={30} fill="#18191d" />
      <rect x={-312} y={820} width={22} height={18} rx={4} fill="#fff6c0" opacity={0.95} />
      <rect x={290} y={824} width={14} height={26} fill="#5a0a0a" />
      <rect x={-300} y={880} width={80} height={14} fill="#2a2a2a" />
      {[-190, 190].map((wx) => (
        <g key={wx}>
          <circle cx={wx} cy={905} r={44} fill="#08090b" stroke="#000" strokeWidth={4} />
          <circle cx={wx} cy={905} r={18} fill="#3a3c42" />
        </g>
      ))}
      {/* gyrophare */}
      <rect x={-90} y={676} width={110} height={18} rx={6} fill="#222" stroke="#000" strokeWidth={3} />
      <rect x={-88} y={672} width={52} height={16} rx={6} fill={gyro && ph ? "#ff2a3a" : "#4a0a10"} />
      <rect x={-32} y={672} width={52} height={16} rx={6} fill={gyro && !ph ? "#3a6aff" : "#0a1a4a"} />
      {gyro > 0 && <circle cx={ph ? -62 : -6} cy={680} r={70} fill={ph ? "url(#lumRouge)" : "url(#lumBleue)"} opacity={0.9} />}
    </g>
  );
};
