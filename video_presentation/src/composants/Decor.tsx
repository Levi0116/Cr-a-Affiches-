import React from "react";
import { AbsoluteFill, interpolate } from "remotion";
import { C, TEXTE, TITRE, entre, ressort, easeOut } from "../theme";
import { Icone } from "./Icone";

const hasard = (n: number) => {
  const x = Math.sin(n * 91.345 + 7.13) * 43758.5453;
  return x - Math.floor(x);
};

/** Fond sombre « obsidienne » avec halo orange et motif géométrique discret. */
export const FondNuit: React.FC<{ f: number; halo?: string; motif?: boolean }> = ({ f, halo = C.orange, motif = true }) => (
  <AbsoluteFill style={{ background: `radial-gradient(ellipse 80% 70% at 50% 45%, ${C.nuit2} 0%, ${C.nuit} 70%)` }}>
    <div style={{
      position: "absolute", left: "50%", top: "45%", width: 1400, height: 1400, marginLeft: -700, marginTop: -700, borderRadius: "50%",
      background: `radial-gradient(circle, ${halo}33 0%, ${halo}00 60%)`, transform: `scale(${1 + Math.sin(f / 40) * 0.04})`,
    }} />
    {motif && (
      <svg width="100%" height="100%" style={{ position: "absolute", inset: 0, opacity: 0.07 }}>
        <defs>
          <pattern id="losanges" width="90" height="90" patternUnits="userSpaceOnUse" patternTransform={`translate(${f * 0.4} 0)`}>
            <path d="M45 10 L80 45 L45 80 L10 45 Z" fill="none" stroke={C.creme} strokeWidth="2" />
            <path d="M45 32 L58 45 L45 58 L32 45 Z" fill={C.creme} />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#losanges)" />
      </svg>
    )}
    <Particules f={f} />
  </AbsoluteFill>
);

/** Particules lumineuses (bokeh) qui montent doucement. */
export const Particules: React.FC<{ f: number; n?: number; couleur?: string }> = ({ f, n = 26, couleur = C.accentLumiere }) => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
    {Array.from({ length: n }).map((_, i) => {
      const x = hasard(i) * 1920;
      const vitesse = 0.3 + hasard(i + 50) * 0.8;
      const y = 1180 - ((f * vitesse + hasard(i + 100) * 1300) % 1300);
      const r = 3 + hasard(i + 200) * 9;
      const o = 0.15 + hasard(i + 300) * 0.35;
      return (
        <div key={i} style={{
          position: "absolute", left: x + Math.sin((f + i * 40) / 50) * 30, top: y, width: r * 2, height: r * 2, borderRadius: "50%",
          background: couleur, opacity: o, filter: `blur(${r > 8 ? 3 : 1}px)`,
        }} />
      );
    })}
  </AbsoluteFill>
);

/** Guirlande d'ampoules qui scintillent. */
export const Guirlande: React.FC<{ f: number; largeur: number; y: number; creux?: number; x?: number }> = ({ f, largeur, y, creux = 70, x = 0 }) => {
  const n = Math.round(largeur / 110);
  return (
    <svg width={largeur} height={creux + 80} style={{ position: "absolute", left: x, top: y, overflow: "visible" }}>
      <path d={`M0 0 Q${largeur / 2} ${creux * 2} ${largeur} 0`} stroke="#2A1D14" strokeWidth="3" fill="none" />
      {Array.from({ length: n }).map((_, i) => {
        const t = (i + 0.5) / n;
        const bx = largeur * t;
        const by = 2 * t * (1 - t) * creux * 2;
        const lum = 0.75 + 0.25 * Math.sin(f / 9 + i * 1.7);
        return (
          <g key={i}>
            <line x1={bx} y1={by} x2={bx} y2={by + 12} stroke="#2A1D14" strokeWidth="3" />
            <circle cx={bx} cy={by + 26} r={34} fill="#FFC86B" opacity={0.18 * lum} />
            <ellipse cx={bx} cy={by + 24} rx="9" ry="12" fill={`rgba(255,${200 + 30 * lum},${120 + 40 * lum},1)`} opacity={lum} />
          </g>
        );
      })}
    </svg>
  );
};

export const Plante: React.FC<{ x: number; y: number; echelle?: number; f: number }> = ({ x, y, echelle = 1, f }) => (
  <svg width={220 * echelle} height={320 * echelle} viewBox="0 0 220 320" style={{ position: "absolute", left: x, top: y, overflow: "visible" }}>
    <g transform={`rotate(${Math.sin(f / 35) * 1.5} 110 260)`}>
      {[-50, -25, 0, 25, 50, -38, 38].map((a, i) => (
        <path key={i} d="M110 260 Q100 160 110 40 Q140 150 110 260 Z" fill={i % 2 ? "#1F6B3A" : "#2E8B4E"} transform={`rotate(${a} 110 260)`} />
      ))}
    </g>
    <path d="M60 250 L160 250 L146 320 L74 320 Z" fill="#C2562A" />
    <rect x="54" y="244" width="112" height="16" rx="4" fill="#D96A3A" />
  </svg>
);

export const Bouteille: React.FC<{ x: number; y: number; couleur: string; etiquette: string; h?: number; style?: React.CSSProperties }> = ({ x, y, couleur, etiquette, h = 150, style }) => (
  <svg width={h * 0.36} height={h} viewBox="0 0 54 150" style={{ position: "absolute", left: x, top: y, overflow: "visible", ...style }}>
    <rect x="21" y="0" width="12" height="10" rx="2" fill="#C9A54A" />
    <path d="M20 10 L34 10 L34 40 Q50 52 50 70 L50 142 Q50 150 42 150 L12 150 Q4 150 4 142 L4 70 Q4 52 20 40 Z" fill={couleur} />
    <rect x="4" y="82" width="46" height="36" fill={etiquette} />
    <path d="M10 60 L10 140" stroke="rgba(255,255,255,0.35)" strokeWidth="5" strokeLinecap="round" />
  </svg>
);

/** Étagère de bar garnie de bouteilles. `masquees` : indices disparus. */
export const EtagereBar: React.FC<{ x: number; y: number; largeur: number; masquees?: (i: number) => number }> = ({ x, y, largeur, masquees }) => {
  const types = [
    ["#5B3A1A", "#F55A0A"], ["#1F5A2E", "#FFE2AE"], ["#6E2A12", "#FFC23D"], ["#173B6B", "#FFFFFF"], ["#5B3A1A", "#E5484D"],
  ];
  const parRangee = Math.floor((largeur - 40) / 64);
  return (
    <div style={{ position: "absolute", left: x, top: y, width: largeur, height: 420 }}>
      {[0, 1].map((r) => (
        <React.Fragment key={r}>
          {Array.from({ length: parRangee }).map((_, i) => {
            const idx = r * parRangee + i;
            const o = masquees ? masquees(idx) : 1;
            const [c, e] = types[(idx * 3 + r) % types.length];
            return <Bouteille key={i} x={30 + i * 64} y={r * 200 + 20 + (1 - o) * -30} couleur={c} etiquette={e} style={{ opacity: o }} />;
          })}
          <div style={{ position: "absolute", left: 0, top: r * 200 + 170, width: largeur, height: 22, background: "linear-gradient(180deg,#8A5A2E,#5E3A1A)", borderRadius: 4, boxShadow: "0 10px 20px rgba(0,0,0,0.3)" }} />
        </React.Fragment>
      ))}
    </div>
  );
};

/** Intérieur du maquis : mur chaud, sol, guirlande, plantes. */
export const SalleMaquis: React.FC<{ f: number; largeur?: number; teinte?: number }> = ({ f, largeur = 1920, teinte = 0 }) => (
  <div style={{ position: "absolute", left: 0, top: 0, width: largeur, height: 1080, overflow: "hidden" }}>
    <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg,#3B2416 0%,#5A3620 55%,#2E1C12 100%)" }} />
    {/* Bandeau motif sur le mur */}
    <svg width={largeur} height="80" style={{ position: "absolute", top: 520, left: 0, opacity: 0.35 }}>
      <defs>
        <pattern id="frise" width="80" height="80" patternUnits="userSpaceOnUse">
          <path d="M0 40 L20 20 L40 40 L60 20 L80 40 L60 60 L40 40 L20 60 Z" fill="none" stroke="#FFB067" strokeWidth="3" />
        </pattern>
      </defs>
      <rect width={largeur} height="80" fill="url(#frise)" />
    </svg>
    {/* Sol */}
    <div style={{ position: "absolute", left: 0, top: 760, width: largeur, height: 320, background: "linear-gradient(180deg,#6B4425,#3A2414)" }} />
    {Array.from({ length: Math.ceil(largeur / 240) }).map((_, i) => (
      <div key={i} style={{ position: "absolute", left: i * 240, top: 760, width: 2, height: 320, background: "rgba(0,0,0,0.18)", transform: "skewX(-20deg)" }} />
    ))}
    {/* Lumière chaude */}
    <div style={{ position: "absolute", inset: 0, background: "radial-gradient(ellipse 60% 50% at 50% 20%, rgba(255,170,80,0.25), rgba(0,0,0,0) 70%)" }} />
    <Guirlande f={f} largeur={largeur} y={40} creux={60} />
    <div style={{ position: "absolute", inset: 0, background: `rgba(11,21,16,${teinte})` }} />
  </div>
);

export const TableResto: React.FC<{ x: number; y: number; largeur?: number; children?: React.ReactNode }> = ({ x, y, largeur = 420, children }) => (
  <div style={{ position: "absolute", left: x, top: y, width: largeur, height: 260 }}>
    {children}
    <div style={{ position: "absolute", left: largeur * 0.46, top: 70, width: largeur * 0.08, height: 190, background: "#3A2414" }} />
    <div style={{ position: "absolute", left: largeur * 0.3, top: 240, width: largeur * 0.4, height: 20, borderRadius: 10, background: "#2A1A0E" }} />
    <svg width={largeur} height="90" style={{ position: "absolute", left: 0, top: 0 }}>
      <defs>
        <pattern id="nappe" width="30" height="30" patternUnits="userSpaceOnUse">
          <rect width="30" height="30" fill="#FFF3D6" />
          <rect width="15" height="15" fill="#F55A0A" opacity="0.85" />
          <rect x="15" y="15" width="15" height="15" fill="#F55A0A" opacity="0.85" />
        </pattern>
      </defs>
      <path d={`M0 10 L${largeur} 10 L${largeur - 10} 84 L10 84 Z`} fill="url(#nappe)" />
      <rect x="0" y="0" width={largeur} height="16" rx="6" fill="#FFF3D6" />
    </svg>
  </div>
);

/** Bulle de dialogue qui apparaît en rebondissant. */
export const Bulle: React.FC<{
  f: number; debut: number; fin?: number; x: number; y: number; texte: React.ReactNode; queue?: "gauche" | "droite" | "bas";
  couleur?: string; couleurTexte?: string; largeurMax?: number; taille?: number;
}> = ({ f, debut, fin = 99999, x, y, texte, queue = "bas", couleur = "#FFFFFF", couleurTexte = C.texte, largeurMax = 620, taille = 44 }) => {
  if (f < debut) return null;
  const s = ressort(f, debut, 12, 170);
  const o = interpolate(f, [fin - 8, fin], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const origine = queue === "gauche" ? "0% 100%" : queue === "droite" ? "100% 100%" : "50% 100%";
  return (
    <div style={{
      position: "absolute", left: x, top: y, transform: `translate(${queue === "droite" ? "-100%" : queue === "bas" ? "-50%" : "0"}, -100%) scale(${s})`,
      transformOrigin: origine, opacity: o, maxWidth: largeurMax,
    }}>
      <div style={{
        background: couleur, color: couleurTexte, padding: "26px 36px", borderRadius: 36, fontFamily: TEXTE, fontWeight: 700, fontSize: taille,
        lineHeight: 1.2, boxShadow: "0 24px 50px rgba(0,0,0,0.3)", position: "relative",
      }}>
        {texte}
        <svg width="50" height="40" style={{
          position: "absolute", bottom: -32,
          left: queue === "gauche" ? 40 : queue === "droite" ? undefined : "50%", right: queue === "droite" ? 40 : undefined,
          marginLeft: queue === "bas" ? -25 : 0, transform: queue === "droite" ? "scaleX(-1)" : undefined,
        }}>
          <path d="M0 0 L50 0 L8 38 Z" fill={couleur} />
        </svg>
      </div>
    </div>
  );
};

/** Pastille (problème en rouge, avantage en vert…). */
export const Puce: React.FC<{ f: number; debut: number; texte: string; icone: number; couleur: string; taille?: number; style?: React.CSSProperties; sombre?: boolean }> = ({
  f, debut, texte, icone, couleur, taille = 44, style, sombre = false,
}) => {
  const s = ressort(f, debut, 12, 160);
  const o = entre(f, debut, 8);
  return (
    <div style={{
      display: "inline-flex", alignItems: "center", gap: taille * 0.4, padding: `${taille * 0.36}px ${taille * 0.7}px ${taille * 0.36}px ${taille * 0.4}px`,
      borderRadius: 999, background: sombre ? "rgba(11,21,16,0.88)" : "#FFFFFF", border: `3px solid ${couleur}`,
      boxShadow: `0 20px 40px rgba(0,0,0,0.3), 0 0 30px ${couleur}44`, transform: `scale(${s})`, opacity: o,
      fontFamily: TEXTE, fontWeight: 700, fontSize: taille, color: sombre ? "#fff" : C.texte, whiteSpace: "nowrap", ...style,
    }}>
      <span style={{ width: taille * 1.5, height: taille * 1.5, borderRadius: "50%", background: couleur, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Icone code={icone} taille={taille * 0.95} couleur="#fff" />
      </span>
      {texte}
    </div>
  );
};

/** Titre d'étape « 1 · La serveuse prend la commande ». */
export const TitreEtape: React.FC<{ f: number; numero: number; titre: string; fin: number; clair?: boolean }> = ({ f, numero, titre, fin, clair = false }) => {
  const e = entre(f, 4, 22);
  const s = interpolate(f, [fin - 12, fin], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const largeurLigne = interpolate(f, [10, 40], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: easeOut });
  return (
    <div style={{ position: "absolute", left: 100, top: 90, display: "flex", alignItems: "center", gap: 30, opacity: e * s, transform: `translateX(${(1 - e) * -60}px)` }}>
      <div style={{
        width: 120, height: 120, borderRadius: 36, background: C.orange, display: "flex", alignItems: "center", justifyContent: "center",
        fontFamily: TITRE, fontWeight: 800, fontSize: 72, color: "#fff", boxShadow: `0 20px 50px ${C.orange}66`, transform: `scale(${ressort(f, 4, 10, 160)})`,
      }}>{numero}</div>
      <div>
        <div style={{ fontFamily: TEXTE, fontWeight: 700, fontSize: 32, letterSpacing: 6, color: C.orangeClair, textTransform: "uppercase" }}>Comment ça marche</div>
        <div style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 84, color: clair ? C.texte : "#fff", lineHeight: 1.05, textShadow: clair ? "none" : "0 6px 30px rgba(0,0,0,0.5)" }}>{titre}</div>
        <div style={{ height: 8, width: 260 * largeurLigne, background: C.orange, borderRadius: 4, marginTop: 12 }} />
      </div>
    </div>
  );
};

/** Légende en bas d'écran, mots qui apparaissent un à un. */
export const Legende: React.FC<{ f: number; debut: number; fin: number; texte: string; accent?: string[]; clair?: boolean; y?: number }> = ({
  f, debut, fin, texte, accent = [], clair = false, y = 930,
}) => {
  if (f < debut || f > fin + 2) return null;
  const mots = texte.split(" ");
  const sortie = interpolate(f, [fin - 10, fin], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <div style={{ position: "absolute", left: 100, right: 100, top: y, display: "flex", justifyContent: "center", opacity: sortie }}>
      <div style={{
        padding: "22px 44px", borderRadius: 28, background: clair ? "rgba(255,255,255,0.94)" : "rgba(11,21,16,0.82)",
        border: `2px solid ${clair ? "rgba(11,58,28,0.12)" : "rgba(255,226,174,0.18)"}`, boxShadow: "0 24px 60px rgba(0,0,0,0.35)",
        fontFamily: TEXTE, fontWeight: 600, fontSize: 46, color: clair ? C.texte : "#fff", textAlign: "center", lineHeight: 1.25,
      }}>
        {mots.map((m, i) => {
          const e = entre(f, debut + i * 2.2, 10);
          const estAccent = accent.some((a) => m.toLowerCase().includes(a.toLowerCase()));
          return (
            <span key={i} style={{ display: "inline-block", opacity: e, transform: `translateY(${(1 - e) * 16}px)`, marginRight: "0.28em", color: estAccent ? C.orange : undefined, fontWeight: estAccent ? 800 : 600 }}>
              {m}
            </span>
          );
        })}
      </div>
    </div>
  );
};

/** Vignettage léger pour un rendu « cinéma ». */
export const Vignette: React.FC = () => (
  <AbsoluteFill style={{ pointerEvents: "none", background: "radial-gradient(ellipse 75% 70% at 50% 50%, rgba(0,0,0,0) 60%, rgba(0,0,0,0.45) 100%)" }} />
);

/** Canapé : le dos se dessine derrière le personnage, l'assise devant. */
export const CanapeDos: React.FC<{ x: number; y: number; largeur: number }> = ({ x, y, largeur }) => (
  <div style={{ position: "absolute", left: x, top: y, width: largeur, height: 300, borderRadius: "60px 60px 20px 20px", background: "linear-gradient(180deg,#14663F,#0B3A1C)", boxShadow: "0 -6px 0 #1F7A4C inset" }} />
);
export const CanapeAssise: React.FC<{ x: number; y: number; largeur: number }> = ({ x, y, largeur }) => (
  <div style={{ position: "absolute", left: x, top: y, width: largeur, height: 400 }}>
    <div style={{ position: "absolute", left: 40, right: 40, top: 0, height: 110, borderRadius: 36, background: "linear-gradient(180deg,#1A7A4A,#0F5132)" }} />
    <div style={{ position: "absolute", left: 0, right: 0, top: 70, height: 330, borderRadius: 40, background: "linear-gradient(180deg,#0F5132,#082A15)" }} />
    <div style={{ position: "absolute", left: -20, top: -60, width: 110, height: 300, borderRadius: 44, background: "linear-gradient(180deg,#14663F,#0B3A1C)" }} />
    <div style={{ position: "absolute", right: -20, top: -60, width: 110, height: 300, borderRadius: 44, background: "linear-gradient(180deg,#14663F,#0B3A1C)" }} />
  </div>
);
