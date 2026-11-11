import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { Defs } from "./art/Defs";
import { easeOut, lerp, noise } from "./lib/anim";

const OUT = "#0b0a10";
const FONT = "'Arial Black', 'Arial', sans-serif";

const SpeedLines: React.FC<{ color?: string; seed?: number }> = ({ color = "#fff", seed = 0 }) => (
  <g opacity={0.18}>
    {Array.from({ length: 48 }).map((_, i) => {
      const a = (i / 48) * Math.PI * 2 + seed;
      const r1 = 380 + ((i * 37) % 120);
      return <path key={i} d={`M${960 + Math.cos(a) * r1} ${540 + Math.sin(a) * r1 * 0.6} L${960 + Math.cos(a) * 1400} ${540 + Math.sin(a) * 900}`} stroke={color} strokeWidth={4 + (i % 3) * 3} />;
    })}
  </g>
);

const Tag: React.FC<{ text: string; f: number }> = ({ text, f }) => (
  <div style={{ position: "absolute", left: 70, top: 60, padding: "10px 26px", background: "#d50000", color: "#fff", fontFamily: FONT, fontSize: 44, letterSpacing: 3, border: "5px solid #fff", rotate: "-3deg", scale: lerp(f, [0, 6], [1.6, 1], easeOut) }}>
    {text}
  </div>
);

// ---- Inserts indices ----
export const InsertIndices: React.FC = () => {
  const f = useCurrentFrame();
  const k = f < 12 ? 0 : f < 24 ? 1 : 2;
  const lf = f - k * 12;
  const z = lerp(lf, [0, 12], [1.25, 1.05], easeOut);
  return (
    <AbsoluteFill style={{ background: "#0a0a0f" }}>
      <svg viewBox="0 0 1920 1080" width={1920} height={1080} style={{ scale: z }}>
        <Defs />
        <rect width={1920} height={1080} fill={["#2a1a0a", "#1a1408", "#0f1418"][k]} />
        <SpeedLines seed={k} />
        {k === 0 && (
          <g transform="translate(960 560) rotate(-6)">
            <path d="M-360 -180 h720 l30 400 h-780z" fill="#8a7650" stroke={OUT} strokeWidth={10} />
            <path d="M-360 -180 q360 -80 720 0 l-20 80 q-340 -60 -680 0z" fill="#6e5c3c" stroke={OUT} strokeWidth={8} />
            <path d="M-200 -250 h300 l10 160 h-320z" fill="#efe8d4" stroke={OUT} strokeWidth={8} rotate="8" />
            <text x={-140} y={-190} fontFamily={FONT} fontSize={30} fill="#1a3a6a">BORDEREAU</text>
            <path d="M-170 -160 h220 M-170 -130 h180" stroke="#9a9488" strokeWidth={8} />
            <circle cx={30} cy={-130} r={52} fill="none" stroke="#c62828" strokeWidth={10} />
            <text x={30} y={-120} textAnchor="middle" fontFamily={FONT} fontSize={22} fill="#c62828">BANQUE</text>
            <path d="M-300 40 q60 20 120 -10 q40 60 120 20" stroke="#6d0a0a" strokeWidth={14} fill="none" opacity={0.8} />
          </g>
        )}
        {k === 1 && (
          <g transform="translate(960 560) rotate(8)">
            <path d="M-900 -120 h1800 v240 h-1800z" fill="#6b3f26" stroke={OUT} strokeWidth={10} />
            <rect x={-150} y={-150} width={300} height={300} rx={60} fill="#c8961e" stroke={OUT} strokeWidth={10} />
            <circle cx={0} cy={0} r={170} fill="#f2c230" stroke={OUT} strokeWidth={12} />
            <circle cx={0} cy={0} r={130} fill="#1a1a1a" stroke="#c8961e" strokeWidth={10} />
            <path d="M0 0 L0 -90 M0 0 L60 30" stroke="#f2c230" strokeWidth={10} strokeLinecap="round" />
            <path d="M-40 -120 l20 40 M60 -110 l-10 30" stroke="#fff" strokeWidth={6} opacity={0.5} />
            <path d="M-500 60 q40 30 80 -10 q30 40 90 0" stroke="#6d0a0a" strokeWidth={18} fill="none" />
          </g>
        )}
        {k === 2 && (
          <g transform="translate(960 600) rotate(-4)">
            <ellipse cx={0} cy={80} rx={520} ry={150} fill="#6b4b2b" stroke={OUT} strokeWidth={10} />
            <ellipse cx={0} cy={60} rx={470} ry={120} fill="#8a6440" />
            <path d="M-120 60 q-60 -160 -160 -150 M160 60 q60 -140 140 -150" stroke="#3a2a18" strokeWidth={26} fill="none" strokeLinecap="round" />
            <path d="M-20 40 l40 -30 l-10 50z" fill="#2a1d10" />
            <path d="M120 -60 l60 -40 M150 -80 l10 50" stroke="#3a2a18" strokeWidth={10} />
          </g>
        )}
      </svg>
      <Tag text={["INDICE • LE SAC", "INDICE • LA MONTRE", "INDICE • LES SAMARAS"][k]} f={lf} />
    </AbsoluteFill>
  );
};

export const InsertJordans: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{ background: "#0a0a0f" }}>
      <svg viewBox="0 0 1920 1080" width={1920} height={1080} style={{ scale: lerp(f, [0, 45], [1.2, 1.02], easeOut) }}>
        <Defs />
        <rect width={1920} height={1080} fill="#14161c" />
        <rect y={760} width={1920} height={320} fill="#24211f" />
        <SpeedLines />
        {[-1, 1].map((k) => (
          <g key={k} transform={`translate(${960 + k * 330} 560)`}>
            <path d="M-170 -620 h300 l30 640 h-360z" fill="url(#camo)" stroke={OUT} strokeWidth={10} />
            <path d="M-260 300 q-10 -260 70 -300 h200 q90 90 150 200 q110 40 110 100 z" fill="#fbfbf7" stroke={OUT} strokeWidth={12} />
            <path d="M-260 300 h530" stroke="#c9c9c2" strokeWidth={26} />
            <path d="M-180 90 q170 60 300 -10" stroke="#e2e2da" strokeWidth={14} fill="none" />
            <path d="M-120 0 h120 M-110 40 h120" stroke="#d8d8d0" strokeWidth={8} />
            <path d="M-200 -10 l40 -20 M150 120 l50 -30" stroke="#fff" strokeWidth={10} strokeLinecap="round" />
          </g>
        ))}
        <g opacity={0.9 * Math.abs(Math.sin(f / 4))}>
          <path d="M1480 330 l14 40 l40 14 l-40 14 l-14 40 l-14 -40 l-40 -14 l40 -14z" fill="#fff" />
          <path d="M520 420 l10 28 l28 10 l-28 10 l-10 28 l-10 -28 l-28 -10 l28 -10z" fill="#fff" />
        </g>
      </svg>
      <Tag text="INDICE 1 • JORDAN NEUVES SOUS TREILLIS" f={f} />
    </AbsoluteFill>
  );
};

export const InsertHolster: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{ background: "#0a0a0f" }}>
      <svg viewBox="0 0 1920 1080" width={1920} height={1080} style={{ scale: lerp(f, [0, 50], [1.25, 1.03], easeOut) }}>
        <Defs />
        <rect width={1920} height={1080} fill="#16171b" />
        <rect y={200} width={1920} height={240} fill="#202227" />
        <rect y={330} width={1920} height={90} fill="#2a1d12" stroke={OUT} strokeWidth={8} />
        <rect x={1100} y={320} width={120} height={110} rx={10} fill="#8a8f96" stroke={OUT} strokeWidth={8} />
        <SpeedLines />
        <g transform="translate(860 360)">
          <path d="M-150 -40 h300 l-30 640 h-240z" fill="#4a2e18" stroke={OUT} strokeWidth={12} />
          <path d="M-120 -30 h240 l-24 560 h-190z" fill="#5a3a20" />
          <ellipse cx={0} cy={-30} rx={150} ry={46} fill="#0b0805" stroke={OUT} strokeWidth={10} />
          <path d="M150 -30 q120 -80 140 -200 l-40 -10 q-20 100 -110 160z" fill="#4a2e18" stroke={OUT} strokeWidth={10} />
          <circle cx={262} cy={-200} r={16} fill="#c9d1d8" stroke={OUT} strokeWidth={6} />
          <path d="M-100 100 q-6 200 10 380 M100 100 q6 200 -10 380" stroke="#2e1c0e" strokeWidth={8} strokeDasharray="20 16" fill="none" />
        </g>
        <text x={1000} y={720} fontFamily={FONT} fontSize={90} fill="#fff" opacity={0.9} rotate="-4">VIDE !</text>
      </svg>
      <Tag text="INDICE 2 • HOLSTER VIDE" f={f} />
    </AbsoluteFill>
  );
};

// ---- Télé : FLASH INFO ----
export const TeleCU: React.FC = () => {
  const f = useCurrentFrame();
  const ph = Math.floor(f / 5) % 2;
  const glitch = f < 10;
  return (
    <AbsoluteFill style={{ background: "#07070a" }}>
      <svg viewBox="0 0 1920 1080" width={1920} height={1080} style={{ scale: lerp(f, [0, 150], [1.05, 1.15]) }}>
        <Defs />
        <rect width={1920} height={1080} fill="#16120e" />
        <rect x={160} y={70} width={1600} height={980} rx={70} fill="#1d1d1f" stroke={OUT} strokeWidth={14} />
        <rect x={230} y={130} width={1460} height={830} rx={40} fill="#0c1a36" />
        {glitch ? (
          Array.from({ length: 30 }).map((_, i) => <rect key={i} x={230} y={130 + i * 28} width={1460} height={14} fill={["#7b2ff7", "#fff", "#2ff7c8", "#111"][(i + f) % 4]} opacity={0.6} />)
        ) : (
          <g>
            <rect x={230} y={130} width={1460} height={830} rx={40} fill="#0f2350" />
            <rect x={290} y={180} width={300} height={70} fill="#d50000" />
            <text x={440} y={230} textAnchor="middle" fontFamily={FONT} fontSize={40} fill="#fff">EN DIRECT</text>
            <circle cx={620} cy={215} r={14} fill="#ff1744" opacity={f % 30 < 15 ? 1 : 0.2} />
            {/* silhouette de présentateur */}
            <circle cx={960} cy={420} r={110} fill="#1a2a4a" />
            <path d="M760 760 q0 -220 200 -230 q200 10 200 230z" fill="#1a2a4a" />
            <rect x={230} y={700} width={1460} height={190} fill="#d50000" />
            <rect x={230} y={700} width={420} height={190} fill="#8a0000" />
            <text x={440} y={815} textAnchor="middle" fontFamily={FONT} fontSize={62} fill="#fff">FLASH INFO</text>
            <text x={690} y={790} fontFamily={FONT} fontSize={52} fill="#fff">BRAQUAGE ANGRÉ 8è TRANCHE</text>
            <text x={690} y={850} fontFamily="Arial" fontWeight={700} fontSize={34} fill="#ffd2d2">Les malfaiteurs sont en fuite • Prudence</text>
            <rect x={230} y={890} width={1460} height={56} fill="#111" />
            <text x={1700 - ((f * 9) % 2600)} y={930} fontFamily="Arial" fontWeight={700} fontSize={32} fill="#fff">
              DERNIÈRE MINUTE • Un véhicule noir sans plaque signalé à Yopougon • Les forces de l'ordre appellent à la vigilance •
            </text>
          </g>
        )}
        {Array.from({ length: 40 }).map((_, i) => <rect key={i} x={230} y={130 + i * 21} width={1460} height={3} fill="#000" opacity={0.18} />)}
        <rect x={230} y={130} width={1460} height={830} rx={40} fill={ph ? "#ff1030" : "#1040ff"} opacity={0.12} />
        <path d="M300 160 q200 -20 380 40 l-300 300z" fill="#fff" opacity={0.05} />
      </svg>
      <div style={{ position: "absolute", inset: 0, background: `radial-gradient(circle at ${ph ? 15 : 85}% 40%, ${ph ? "rgba(255,20,40,0.35)" : "rgba(30,70,255,0.35)"}, transparent 60%)` }} />
      <div style={{ position: "absolute", inset: 0, opacity: 0.1 + 0.05 * noise(f, 3), background: "#fff", mixBlendMode: "overlay" }} />
    </AbsoluteFill>
  );
};

// ---- Carton titre ----
export const Titre: React.FC = () => {
  const f = useCurrentFrame();
  const op = lerp(f, [0, 12, 95, 115], [0, 1, 1, 0]);
  const chars = Math.floor(lerp(f, [8, 40], [0, 17]));
  return (
    <AbsoluteFill style={{ opacity: op, justifyContent: "flex-start", padding: "70px 0 0 90px" }}>
      <div style={{ fontFamily: FONT, color: "#ffd23f", fontSize: 34, letterSpacing: 8, textShadow: "0 0 18px #000" }}>ÉPISODE 1</div>
      <div style={{ fontFamily: FONT, color: "#fff", fontSize: 76, letterSpacing: 2, textShadow: "0 4px 24px #000", translate: `${lerp(f, [0, 20], [-40, 0], easeOut)}px 0` }}>
        LA TENUE MOUSSE PAS DROIT
      </div>
      <div style={{ fontFamily: "monospace", color: "#e8d27a", fontSize: 34, marginTop: 10, textShadow: "0 0 10px #000" }}>{"YOPOUGON • 01H30".slice(0, chars)}</div>
    </AbsoluteFill>
  );
};

// ---- Choix interactif ----
export const Choix: React.FC = () => {
  const f = useCurrentFrame();
  const inA = lerp(f, [30, 44], [0, 1], easeOut);
  const inB = lerp(f, [44, 58], [0, 1], easeOut);
  const blinkA = Math.floor(f / 12) % 2 === 0;
  const fin = lerp(f, [405, 425], [0, 1]);
  const Btn: React.FC<{ letter: string; title: string; sub: string; color: string; on: boolean; k: number }> = ({ letter, title, sub, color, on, k }) => (
    <div
      style={{
        width: 760,
        padding: "26px 34px",
        background: on ? color : "#111",
        border: `8px solid ${color}`,
        boxShadow: on ? `0 0 60px ${color}` : "none",
        borderRadius: 26,
        display: "flex",
        alignItems: "center",
        gap: 30,
        scale: k,
        rotate: letter === "A" ? "-2deg" : "2deg",
      }}
    >
      <div style={{ width: 130, height: 130, borderRadius: 999, background: "#fff", color: "#111", fontFamily: FONT, fontSize: 96, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>{letter}</div>
      <div>
        <div style={{ fontFamily: FONT, fontSize: 30, color: on ? "#111" : color, letterSpacing: 2 }}>OPTION {letter}</div>
        <div style={{ fontFamily: FONT, fontSize: 50, color: "#fff", lineHeight: 1.05, textShadow: "0 3px 0 #000" }}>{title}</div>
        <div style={{ fontFamily: "Arial", fontWeight: 800, fontSize: 30, color: on ? "#111" : "#ddd" }}>{sub}</div>
      </div>
    </div>
  );
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", top: 60, width: "100%", textAlign: "center", fontFamily: FONT, fontSize: 64, color: "#fff", textShadow: "0 6px 0 #000, 0 0 30px #000", scale: lerp(f, [4, 18], [2, 1], easeOut), opacity: lerp(f, [4, 10], [0, 1]) }}>
        TU ES À LA PLACE DE YAO…
      </div>
      <div style={{ position: "absolute", bottom: 200, width: "100%", display: "flex", justifyContent: "space-around" }}>
        <Btn letter="A" title="TAPER LA BOUCHE" sub="Mentir aux faux gonmons" color="#2ecc40" on={blinkA} k={inA} />
        <Btn letter="B" title="VENDRE LE DJO" sub="Faire un signe du menton" color="#ff2a3a" on={!blinkA} k={inB} />
      </div>
      <div style={{ position: "absolute", bottom: 90, width: "100%", textAlign: "center", fontFamily: FONT, fontSize: 40, color: "#ffd23f", opacity: lerp(f, [200, 215], [0, 1]), textShadow: "0 4px 0 #000" }}>
        💬 METS A OU B EN COMMENTAIRE + TES PREUVES !
      </div>
      <AbsoluteFill style={{ background: "#000", opacity: fin, justifyContent: "center", alignItems: "center" }}>
        <div style={{ fontFamily: FONT, color: "#fff", fontSize: 80, letterSpacing: 6 }}>À SUIVRE…</div>
        <div style={{ fontFamily: FONT, color: "#ffd23f", fontSize: 34, letterSpacing: 6, marginTop: 10 }}>ÉPISODE 2 — TON CHOIX DÉCIDE</div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// fissures de l'écran gelé
export const Fissures: React.FC = () => {
  const f = useCurrentFrame();
  const p = lerp(f, [0, 8], [0, 1], easeOut);
  return (
    <svg viewBox="0 0 1920 1080" width={1920} height={1080} style={{ position: "absolute", inset: 0 }}>
      <g stroke="#fff" strokeWidth={4} fill="none" opacity={0.85} strokeDasharray={3000} strokeDashoffset={3000 * (1 - p)}>
        <path d="M1300 380 L1120 260 L980 300 L760 120 L620 160 M1300 380 L1500 240 L1700 260 L1920 120 M1300 380 L1420 560 L1380 760 L1520 1080 M1300 380 L1120 520 L860 560 L640 760 L420 820 L0 760 M1300 380 L1700 520 L1920 500 M1120 260 L1100 0 M860 560 L900 840 L820 1080" />
        <path d="M1300 380 L1240 300 L1180 330 M1300 380 L1380 330 M1300 380 L1340 450" strokeWidth={8} />
      </g>
      <circle cx={1300} cy={380} r={18 * p} fill="#fff" opacity={0.8} />
    </svg>
  );
};
